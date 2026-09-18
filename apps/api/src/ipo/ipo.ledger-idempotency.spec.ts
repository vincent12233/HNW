import { Prisma } from '../generated/prisma/client';
import { IpoService } from './ipo.service';

describe('IpoService publication ledger idempotency', () => {
  function setup(options?: { existingLedger?: unknown }) {
    const application: any = {
      id: 'app-1',
      status: 'PENDING',
      draftQuantity: 5,
      draftPrice: 10,
      publishedAt: null,
      ipo: {
        id: 'ipo-1',
        instrumentId: 'stock',
        symbol: 'ABC',
        issuePrice: 10,
        availableShares: 1000,
      },
      account: {
        id: 'account',
        userId: 'customer',
        cashBalance: 100,
        frozenBalance: 0,
        buyingPower: 100,
        user: { assignedBusinessId: 'business' },
      },
    };
    const tx = {
      ipoApplication: {
        findUnique: jest.fn().mockImplementation(async () => application),
        aggregate: jest.fn().mockResolvedValue({ _sum: { draftQuantity: 0 } }),
        updateMany: jest.fn().mockImplementation(async ({ data }) => {
          Object.assign(application, data);
          return { count: 1 };
        }),
        findUniqueOrThrow: jest
          .fn()
          .mockImplementation(async () => application),
      },
      ipo: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      account: { update: jest.fn() },
      ipoDebt: { create: jest.fn() },
      notification: { create: jest.fn() },
      auditLog: { create: jest.fn() },
      order: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'order-1' }),
      },
      trade: { create: jest.fn() },
      position: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(options?.existingLedger ?? null),
        create: jest.fn().mockResolvedValue({
          id: 'ledger-1',
          idempotencyKey: 'IPO_PUBLICATION:app-1',
        }),
      },
    };
    const service = new IpoService({
      $transaction: (fn: any) => fn(tx),
    } as any);
    return { service, tx, application };
  }

  it('writes IPO_PUBLICATION:{applicationId} once when debiting', async () => {
    const { service, tx } = setup();
    const result = await service.publish(['app-1'], 'actor', 'business');
    expect(result.published).toBe(1);
    expect(tx.accountTransaction.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        type: 'TRADE_SETTLEMENT',
        idempotencyKey: 'IPO_PUBLICATION:app-1',
        referenceId: 'app-1',
      }),
    });
    expect(tx.accountTransaction.create).toHaveBeenCalledTimes(1);
  });

  it('allows a second distinct IPO application to create its own ledger', async () => {
    const first = setup();
    const second = setup();
    second.application.id = 'app-2';
    second.tx.accountTransaction.create.mockResolvedValue({
      id: 'ledger-2',
      idempotencyKey: 'IPO_PUBLICATION:app-2',
    });

    await first.service.publish(['app-1'], 'actor', 'business');
    await second.service.publish(['app-2'], 'actor', 'business');

    expect(
      first.tx.accountTransaction.create.mock.calls[0][0].data.idempotencyKey,
    ).toBe('IPO_PUBLICATION:app-1');
    expect(
      second.tx.accountTransaction.create.mock.calls[0][0].data.idempotencyKey,
    ).toBe('IPO_PUBLICATION:app-2');
  });

  it('does not count a publication when ledger already exists for the application', async () => {
    const { service, tx } = setup({
      existingLedger: {
        id: 'existing',
        idempotencyKey: 'IPO_PUBLICATION:app-1',
      },
    });
    tx.accountTransaction.findUnique.mockResolvedValue({
      id: 'existing',
      idempotencyKey: 'IPO_PUBLICATION:app-1',
    });

    const result = await service.publish(['app-1'], 'actor', 'business');
    expect(result.published).toBe(0);
    expect(result.results[0]).toMatchObject({
      id: 'app-1',
      published: false,
      message: 'IPO publication settlement already recorded',
    });
    expect(tx.accountTransaction.create).not.toHaveBeenCalled();
  });
});
