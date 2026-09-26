import { Test, TestingModule } from '@nestjs/testing';
import { WithdrawalService } from './withdrawal.service';
import { WithdrawalPinService } from '../client-experience/withdrawal-pin.service';
import { AuditService } from '../audit/audit.service';

describe('WithdrawalService', () => {
  let service: WithdrawalService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [WithdrawalService],
    })
      .useMocker((token) =>
        token === WithdrawalPinService
          ? { verify: jest.fn().mockResolvedValue(undefined) }
          : token === AuditService
            ? { createLog: jest.fn().mockResolvedValue({ id: 'audit-1' }) }
            : {},
      )
      .compile();

    service = module.get<WithdrawalService>(WithdrawalService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('does not create or freeze funds when PIN verification fails', async () => {
    (service as any).pins.verify.mockRejectedValue(
      new Error('Incorrect withdrawal PIN'),
    );
    const transaction = jest.fn();
    (service as any).prisma = { $transaction: transaction };
    await expect(
      service.createRequest(
        'user-1',
        100,
        'Bank',
        '123456789',
        'TEST0001234',
        undefined,
        undefined,
        '000000',
      ),
    ).rejects.toThrow('Incorrect withdrawal PIN');
    expect(transaction).not.toHaveBeenCalled();
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
          frozenBalance: 0,
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
    const createUpdate = transaction.account.update.mock.calls[0][0];
    expect(createUpdate.where).toEqual({ id: 'account-1' });
    expect(Number(createUpdate.data.buyingPower.decrement)).toBe(100);
    expect(Number(createUpdate.data.frozenBalance.increment)).toBe(100);
  });

  it('replays an existing withdrawal for the same client idempotency key', async () => {
    const existing = {
      id: 'withdrawal-existing',
      orderNo: 'WD-EXISTING',
      amount: 100,
      bankName: 'Test Bank',
      accountNumber: '1234567890',
      ifscCode: 'TEST0001234',
      upiId: null,
    };
    const transaction = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'account-1',
          cashBalance: 1000,
          buyingPower: 1000,
          frozenBalance: 0,
        }),
        update: jest.fn(),
      },
      $executeRaw: jest.fn().mockResolvedValue(1),
      withdrawalRequest: {
        findFirst: jest.fn().mockResolvedValue(existing),
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
        undefined,
        undefined,
        '123456',
        'APP-WITHDRAWAL-1234',
      ),
    ).resolves.toBe(existing);
    expect(transaction.withdrawalRequest.findFirst).toHaveBeenCalledWith({
      where: {
        accountId: 'account-1',
        clientRequestId: 'APP-WITHDRAWAL-1234',
      },
    });
    expect(transaction.withdrawalRequest.create).not.toHaveBeenCalled();
    expect(transaction.account.update).not.toHaveBeenCalled();
    expect(transaction.notification.create).not.toHaveBeenCalled();
  });

  it('rejects reuse of an idempotency key with a different payload', async () => {
    const transaction = {
      account: {
        findUnique: jest
          .fn()
          .mockResolvedValue({
            id: 'account-1',
            cashBalance: 1000,
            buyingPower: 1000,
            frozenBalance: 0,
          }),
        update: jest.fn(),
      },
      $executeRaw: jest.fn().mockResolvedValue(1),
      withdrawalRequest: {
        findFirst: jest
          .fn()
          .mockResolvedValue({
            id: 'withdrawal-existing',
            amount: 200,
            bankName: 'Other Bank',
            accountNumber: '9999999999',
            ifscCode: 'OTHER000001',
            upiId: null,
          }),
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
        undefined,
        undefined,
        '123456',
        'APP-WITHDRAWAL-1234',
      ),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'IDEMPOTENCY_KEY_REUSED' }),
    });
    expect(transaction.withdrawalRequest.create).not.toHaveBeenCalled();
    expect(transaction.account.update).not.toHaveBeenCalled();
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
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({}),
      },
      notification: { create: jest.fn().mockResolvedValue({}) },
    };
    (service as any).prisma = {
      $transaction: jest.fn((callback: (tx: any) => unknown) =>
        callback(transaction),
      ),
    };

    await service.approveWithdrawal('withdrawal-1');

    const approveUpdate = transaction.account.update.mock.calls[0][0];
    expect(approveUpdate.where).toEqual({ id: 'account-1' });
    expect(Number(approveUpdate.data.cashBalance)).toBe(800);
    expect(Number(approveUpdate.data.frozenBalance.decrement)).toBe(200);
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

    const rejectUpdate = transaction.account.update.mock.calls[0][0];
    expect(rejectUpdate.where).toEqual({ id: 'account-1' });
    expect(Number(rejectUpdate.data.buyingPower.increment)).toBe(200);
    expect(Number(rejectUpdate.data.frozenBalance.decrement)).toBe(200);
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
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
      notification: { create: jest.fn() },
    };
    (service as any).prisma = {
      $transaction: jest.fn((callback: (tx: any) => unknown) =>
        callback(transaction),
      ),
    };

    await expect(service.approveWithdrawal('withdrawal-1')).rejects.toThrow(
      'Withdrawal already processed',
    );
    expect(transaction.account.update).not.toHaveBeenCalled();
    expect(transaction.accountTransaction.create).not.toHaveBeenCalled();
    expect(transaction.notification.create).not.toHaveBeenCalled();
  });
});
