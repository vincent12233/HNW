import { ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { ApprovalService } from './approval.service';

describe('ApprovalService ledger idempotency', () => {
  function setup(existingLedger: unknown = null) {
    const account = {
      id: 'account',
      accountNumber: 'ACC1',
      userId: 'client',
      cashBalance: new Prisma.Decimal(100),
      buyingPower: new Prisma.Decimal(100),
      frozenBalance: new Prisma.Decimal(0),
      user: { usedInviteCode: null },
    };
    const request = {
      id: 'approval-1',
      status: 'PENDING',
      resource: 'ACCOUNT_BALANCE',
      action: 'ACCOUNT_CREDIT',
      requestedById: 'admin-requester',
      expiresAt: new Date(Date.now() + 60_000),
      payload: {
        accountNumber: 'ACC1',
        amount: '25',
        referenceId: 'REF-APPR-1',
        note: 'credit',
      },
    };
    const created = { id: 'ledger-1', idempotencyKey: 'ADJUSTMENT:REF-APPR-1' };
    const tx = {
      approvalRequest: {
        findUnique: jest.fn().mockResolvedValue(request),
        update: jest.fn().mockResolvedValue({
          ...request,
          status: 'APPROVED',
          decidedById: 'finance-1',
        }),
      },
      account: {
        findUnique: jest.fn().mockResolvedValue(account),
        update: jest.fn().mockResolvedValue(account),
      },
      user: {
        findUnique: jest.fn().mockResolvedValue({ role: 'FINANCE' }),
      },
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(existingLedger),
        create: jest.fn().mockResolvedValue(created),
      },
      notification: { create: jest.fn() },
      ipoDebt: { findMany: jest.fn().mockResolvedValue([]) },
    };
    const prisma = { $transaction: (fn: any) => fn(tx) };
    const service = new ApprovalService(
      prisma as any,
      { createLog: jest.fn() } as any,
    );
    return { service, tx, created };
  }

  it('writes ADJUSTMENT key once for an approved credit', async () => {
    const { service, tx, created } = setup();
    await service.decide('approval-1', 'finance-1', 'APPROVED');
    expect(tx.accountTransaction.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        idempotencyKey: 'ADJUSTMENT:REF-APPR-1',
        type: 'ADMIN_CREDIT',
        referenceId: 'REF-APPR-1',
      }),
    });
    expect(tx.accountTransaction.create).toHaveBeenCalledTimes(1);
    expect(created.idempotencyKey).toBe('ADJUSTMENT:REF-APPR-1');
  });

  it('rejects duplicate approval reference without a second ledger row', async () => {
    const { service, tx } = setup({
      id: 'existing',
      idempotencyKey: 'ADJUSTMENT:REF-APPR-1',
    });
    await expect(
      service.decide('approval-1', 'finance-1', 'APPROVED'),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(tx.account.update).not.toHaveBeenCalled();
    expect(tx.accountTransaction.create).not.toHaveBeenCalled();
  });
});
