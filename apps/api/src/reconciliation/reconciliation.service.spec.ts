import { BadRequestException } from '@nestjs/common';
import { ReconciliationService } from './reconciliation.service';

describe('ReconciliationService', () => {
  const createPrisma = () => {
    const tx = {
      $queryRaw: jest.fn(),
      reconciliationRun: { update: jest.fn() },
      reconciliationIssue: { createMany: jest.fn() },
    };
    const prisma = {
      reconciliationRun: {
        create: jest.fn().mockResolvedValue({ id: 'run-1' }),
        update: jest.fn(),
        findUnique: jest.fn(),
      },
      reconciliationIssue: { update: jest.fn() },
      $transaction: jest.fn(async (callback: (value: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    return { prisma, tx };
  };

  it('records detected differences without updating accounts, positions, orders, or trades', async () => {
    const { prisma, tx } = createPrisma();
    tx.$queryRaw
      .mockResolvedValueOnce([{ locked: true }])
      .mockResolvedValueOnce([
        {
          entityId: 'acct-1',
          summary: 'cash mismatch',
          details: { difference: '10.00' },
        },
      ])
      .mockResolvedValue([]);
    const service = new ReconciliationService(prisma as never);

    await expect(service.run()).resolves.toEqual({
      skipped: false,
      runId: 'run-1',
      issueCount: 1,
    });

    expect(tx.reconciliationIssue.createMany).toHaveBeenCalledTimes(1);
    expect(tx.reconciliationRun.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'COMPLETED', issueCount: 1 }),
      }),
    );
    expect(tx).not.toHaveProperty('account.update');
    expect(tx).not.toHaveProperty('position.update');
    expect(tx).not.toHaveProperty('order.update');
    expect(tx).not.toHaveProperty('trade.update');
  });

  it('skips duplicate scheduler execution when the advisory lock is unavailable', async () => {
    const { prisma, tx } = createPrisma();
    tx.$queryRaw.mockResolvedValueOnce([{ locked: false }]);
    const service = new ReconciliationService(prisma as never);

    await expect(service.run()).resolves.toEqual({
      skipped: true,
      runId: 'run-1',
      issueCount: 0,
    });
    expect(tx.reconciliationIssue.createMany).not.toHaveBeenCalled();
    expect(tx.reconciliationRun.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'SKIPPED' }),
      }),
    );
  });

  it('requires a meaningful acknowledgement note', async () => {
    const { prisma } = createPrisma();
    const service = new ReconciliationService(prisma as never);

    await expect(
      service.acknowledge('issue-1', 'admin-1', ' '),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.reconciliationIssue.update).not.toHaveBeenCalled();
  });
});
