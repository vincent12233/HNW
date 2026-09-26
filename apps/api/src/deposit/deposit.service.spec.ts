import { Test, TestingModule } from '@nestjs/testing';
import { DepositService } from './deposit.service';

describe('DepositService', () => {
  let service: DepositService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [DepositService],
    })
      .useMocker(() => ({}))
      .compile();

    service = module.get<DepositService>(DepositService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('replays a rejected deposit without sending another notification or audit', async () => {
    const transaction = {
      depositRequest: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'deposit-1',
          status: 'REJECTED',
          account: { userId: 'client-1' },
        }),
        updateMany: jest.fn(),
      },
      user: { count: jest.fn().mockResolvedValue(1) },
      notification: { create: jest.fn() },
    };
    (service as any).prisma = {
      $transaction: jest.fn((callback: (tx: any) => unknown) =>
        callback(transaction),
      ),
    };
    (service as any).audit = {
      createLog: jest.fn(),
      findReplayResult: jest.fn().mockResolvedValue({
        message: 'Deposit rejected',
        depositId: 'deposit-1',
      }),
    };

    await expect(
      service.rejectDeposit(
        'deposit-1',
        'different note',
        'finance',
        'FINANCE',
      ),
    ).resolves.toEqual({
      message: 'Deposit rejected',
      depositId: 'deposit-1',
    });
    expect(transaction.depositRequest.updateMany).not.toHaveBeenCalled();
    expect(transaction.notification.create).not.toHaveBeenCalled();
    expect((service as any).audit.createLog).not.toHaveBeenCalled();
  });

  it('replays the winner after a concurrent deposit rejection claim is lost', async () => {
    const transaction = {
      depositRequest: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'deposit-1',
          status: 'PENDING',
          account: { userId: 'client-1' },
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      user: { count: jest.fn().mockResolvedValue(1) },
      notification: { create: jest.fn() },
    };
    (service as any).prisma = {
      depositRequest: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'deposit-1',
          status: 'REJECTED',
          account: { userId: 'client-1' },
        }),
      },
      user: { count: jest.fn().mockResolvedValue(1) },
      $transaction: jest.fn((callback: (tx: any) => unknown) =>
        callback(transaction),
      ),
    };
    (service as any).audit = {
      createLog: jest.fn(),
      findReplayResult: jest.fn().mockResolvedValue({
        message: 'Deposit rejected',
        depositId: 'deposit-1',
      }),
    };

    await expect(
      service.rejectDeposit('deposit-1', 'note', 'finance', 'FINANCE'),
    ).resolves.toEqual({
      message: 'Deposit rejected',
      depositId: 'deposit-1',
    });
    expect(transaction.notification.create).not.toHaveBeenCalled();
    expect((service as any).audit.createLog).not.toHaveBeenCalled();
  });
});
