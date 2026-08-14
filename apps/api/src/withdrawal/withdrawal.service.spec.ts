import { Test, TestingModule } from '@nestjs/testing';
import { WithdrawalService } from './withdrawal.service';

describe('WithdrawalService', () => {
  let service: WithdrawalService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [WithdrawalService],
    })
      .useMocker(() => ({}))
      .compile();

    service = module.get<WithdrawalService>(WithdrawalService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('rejects withdrawals below ₹100', async () => {
    await expect(
      service.createRequest(
        'user-1',
        99.99,
        'Test Bank',
        '1234567890',
        'TEST0001234',
      ),
    ).rejects.toThrow('Minimum withdrawal amount is ₹100');
  });

  it('allows a withdrawal of exactly ₹100', async () => {
    const createdRequest = {
      id: 'withdrawal-1',
      orderNo: 'WD2026081400000001',
    };
    const transaction = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'account-1',
          cashBalance: 100,
          buyingPower: 100,
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      withdrawalRequest: {
        create: jest.fn().mockResolvedValue(createdRequest),
      },
      notification: { create: jest.fn().mockResolvedValue({}) },
    };
    (service as any).prisma = {
      $transaction: jest.fn((callback: (tx: any) => unknown) =>
        callback(transaction),
      ),
    };

    await expect(
      service.createRequest(
        'user-1',
        100,
        'Test Bank',
        '1234567890',
        'TEST0001234',
      ),
    ).resolves.toBe(createdRequest);
    expect(transaction.withdrawalRequest.create).toHaveBeenCalledTimes(1);
    expect(transaction.account.update).toHaveBeenCalledWith({
      where: { id: 'account-1' },
      data: {
        buyingPower: { decrement: 100 },
        frozenBalance: { increment: 100 },
      },
    });
  });

  it('rejects amounts with more than two decimal places', async () => {
    await expect(
      service.createRequest(
        'user-1',
        100.001,
        'Test Bank',
        '1234567890',
        'TEST0001234',
      ),
    ).rejects.toThrow(
      'Withdrawal amount cannot have more than two decimal places',
    );
  });

  it('rejects a withdrawal when available balance is already frozen', async () => {
    const transaction = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'account-1',
          cashBalance: 1000,
          buyingPower: 50,
        }),
        update: jest.fn(),
      },
      withdrawalRequest: {
        create: jest.fn(),
      },
      notification: { create: jest.fn() },
    };
    (service as any).prisma = {
      $transaction: jest.fn((callback: (tx: any) => unknown) =>
        callback(transaction),
      ),
    };

    await expect(
      service.createRequest(
        'user-1',
        100,
        'Test Bank',
        '1234567890',
        'TEST0001234',
      ),
    ).rejects.toThrow('Insufficient available balance');
    expect(transaction.withdrawalRequest.create).not.toHaveBeenCalled();
    expect(transaction.account.update).not.toHaveBeenCalled();
  });

  it('deducts cash and releases the dedicated freeze when approved', async () => {
    const transaction = {
      withdrawalRequest: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'withdrawal-1',
          accountId: 'account-1',
          amount: 200,
          frozenAmount: 200,
          status: 'PENDING',
          orderNo: 'WD1',
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      account: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'account-1',
          userId: 'user-1',
          cashBalance: 1000,
          buyingPower: 800,
          frozenBalance: 200,
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      accountTransaction: { create: jest.fn().mockResolvedValue({}) },
      notification: { create: jest.fn().mockResolvedValue({}) },
    };
    (service as any).prisma = {
      $transaction: jest.fn((callback: (tx: any) => unknown) =>
        callback(transaction),
      ),
    };

    await service.approveWithdrawal('withdrawal-1');

    expect(transaction.account.update).toHaveBeenCalledWith({
      where: { id: 'account-1' },
      data: {
        cashBalance: 800,
        frozenBalance: { decrement: 200 },
      },
    });
    expect(transaction.withdrawalRequest.updateMany).toHaveBeenCalledWith({
      where: { id: 'withdrawal-1', status: 'PENDING' },
      data: { status: 'APPROVED', frozenAmount: 0 },
    });
  });

  it('releases the dedicated freeze when rejected', async () => {
    const transaction = {
      withdrawalRequest: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'withdrawal-1',
          accountId: 'account-1',
          amount: 200,
          frozenAmount: 200,
          status: 'PENDING',
          orderNo: 'WD1',
          note: null,
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      account: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'account-1',
          userId: 'user-1',
          frozenBalance: 200,
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      notification: { create: jest.fn().mockResolvedValue({}) },
    };
    (service as any).prisma = {
      $transaction: jest.fn((callback: (tx: any) => unknown) =>
        callback(transaction),
      ),
    };

    await service.rejectWithdrawal('withdrawal-1', 'Bank verification failed');

    expect(transaction.account.update).toHaveBeenCalledWith({
      where: { id: 'account-1' },
      data: {
        buyingPower: { increment: 200 },
        frozenBalance: { decrement: 200 },
      },
    });
    expect(transaction.withdrawalRequest.updateMany).toHaveBeenCalledWith({
      where: { id: 'withdrawal-1', status: 'PENDING' },
      data: {
        status: 'REJECTED',
        frozenAmount: 0,
        note: 'Bank verification failed',
      },
    });
  });

  it('does not deduct funds when another reviewer already processed it', async () => {
    const transaction = {
      withdrawalRequest: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'withdrawal-1',
          accountId: 'account-1',
          amount: 200,
          frozenAmount: 200,
          status: 'PENDING',
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      account: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'account-1',
          cashBalance: 1000,
          buyingPower: 800,
          frozenBalance: 200,
        }),
        update: jest.fn(),
      },
      accountTransaction: { create: jest.fn() },
      notification: { create: jest.fn() },
    };
    (service as any).prisma = {
      $transaction: jest.fn((callback: (tx: any) => unknown) =>
        callback(transaction),
      ),
    };

    await expect(
      service.approveWithdrawal('withdrawal-1'),
    ).rejects.toThrow('Withdrawal already processed');
    expect(transaction.account.update).not.toHaveBeenCalled();
    expect(transaction.accountTransaction.create).not.toHaveBeenCalled();
    expect(transaction.notification.create).not.toHaveBeenCalled();
  });
});
