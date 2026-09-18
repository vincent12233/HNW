import { Prisma } from '../generated/prisma/client';
import { ApprovalService } from './approval.service';

describe('ApprovalService decide notifies client on credit', () => {
  function setup(creditAmount: number, withDebt = true) {
    const account = {
      id: 'account',
      accountNumber: 'ACC1',
      userId: 'client',
      cashBalance: new Prisma.Decimal(0),
      buyingPower: new Prisma.Decimal(0),
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
        amount: String(creditAmount),
        referenceId: 'REF-APPR',
        note: 'Superadmin credit',
      },
    };
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
        findFirst: jest.fn().mockResolvedValue(null),
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'ledger-1' }),
      },
      notification: { create: jest.fn() },
      ipoDebt: {
        findMany: jest.fn().mockResolvedValue(
          withDebt
            ? [
                {
                  id: 'debt',
                  amount: 100,
                  paidAmount: 0,
                  ipoApplicationId: 'app',
                  ipoApplication: {
                    id: 'app',
                    allocatedQuantity: 10,
                    allocatedPrice: 10,
                    allocatedAmount: 100,
                    ipo: {
                      symbol: 'ABC',
                      instrumentId: 'stock',
                      issuePrice: 10,
                    },
                  },
                },
              ]
            : [],
        ),
        update: jest.fn(),
      },
      ipoApplication: { update: jest.fn() },
      order: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'order' }),
      },
      trade: { create: jest.fn() },
      position: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
    };
    const prisma = {
      $transaction: (fn: any) => fn(tx),
    };
    const service = new ApprovalService(
      prisma as any,
      {
        createLog: jest.fn(),
      } as any,
    );
    return { service, tx };
  }

  it('creates client notification with IPO debt split', async () => {
    const { service, tx } = setup(150);
    const result = await service.decide('approval-1', 'finance-1', 'APPROVED');
    expect(result.ipoRepayment).toBe('100.00');
    expect(result.creditedAmount).toBe('50.00');
    expect(tx.notification.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        userId: 'client',
        type: 'ACCOUNT',
        title: 'Funds credited',
        body: '50.00 added to balance; 100.00 applied to IPO debt.',
        referenceId: 'REF-APPR',
      }),
    });
  });

  it('notifies full cash credit when no debt', async () => {
    const { service, tx } = setup(80, false);
    const result = await service.decide('approval-1', 'finance-1', 'APPROVED');
    expect(result.ipoRepayment).toBe('0.00');
    expect(result.creditedAmount).toBe('80.00');
    expect(tx.notification.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        body: '80.00 has been applied to your account balance.',
      }),
    });
  });
});
