import { randomUUID } from 'crypto';
import {
  auditPostgresEnabled,
  auditPrisma,
} from '../testing/postgres-audit-fixture';
import { ReconciliationService } from './reconciliation.service';

(auditPostgresEnabled ? describe : describe.skip)(
  'Frozen cash reconciliation PostgreSQL snapshot',
  () => {
    const db = auditPrisma();
    const service = new ReconciliationService(db);
    let accountId: string;
    let userId: string;
    let instrumentId: string;
    const runs: string[] = [];
    beforeAll(async () => {
      userId = randomUUID();
      await db.user.create({
        data: {
          id: userId,
          email: `${userId}@test.local`,
          fullName: 'Fixture',
          passwordHash: 'fixture',
        },
      });
      accountId = (
        await db.account.create({
          data: {
            userId,
            accountNumber: randomUUID(),
            cashBalance: 1000,
            buyingPower: 1000,
          },
        })
      ).id;
      instrumentId = (
        await db.instrument.create({
          data: { symbol: randomUUID(), name: 'Fixture', exchange: 'NSE' },
        })
      ).id;
    });
    beforeEach(async () => {
      await db.order.deleteMany({ where: { accountId } });
      await db.withdrawalRequest.deleteMany({ where: { accountId } });
      await db.account.update({
        where: { id: accountId },
        data: { frozenBalance: 0 },
      });
    });
    afterAll(async () => {
      await db.reconciliationRun.deleteMany({ where: { id: { in: runs } } });
      await db.account.delete({ where: { id: accountId } });
      await db.user.delete({ where: { id: userId } });
      await db.instrument.delete({ where: { id: instrumentId } });
      await db.$disconnect();
    });
    async function issues() {
      const result = await service.run();
      runs.push(result.runId);
      return db.reconciliationIssue.findMany({
        where: {
          runId: result.runId,
          entityId: accountId,
          checkType: 'FROZEN_CASH_BUY_ORDERS',
        },
      });
    }
    async function order(
      amount: number,
      status: 'OPEN' | 'PARTIALLY_FILLED' | 'CANCELLED' = 'OPEN',
    ) {
      return db.order.create({
        data: {
          accountId,
          instrumentId,
          clientOrderId: randomUUID(),
          side: 'BUY',
          type: 'LIMIT',
          status,
          quantity: 10,
          filledQuantity: status === 'PARTIALLY_FILLED' ? 5 : 0,
          frozenAmount: amount,
        },
      });
    }
    async function withdrawal(amount: number) {
      return db.withdrawalRequest.create({
        data: { accountId, amount, frozenAmount: amount },
      });
    }
    it.each([
      [0, 0],
      [100, 0],
      [0, 100],
      [100, 200],
    ])(
      'reconciles order %i and withdrawal %i independently',
      async (buy, withdraw) => {
        if (buy) await order(buy);
        if (withdraw) await withdrawal(withdraw);
        await db.account.update({
          where: { id: accountId },
          data: { frozenBalance: buy + withdraw },
        });
        expect(await issues()).toEqual([]);
      },
    );
    it('does not multiply many-to-many totals; uses remaining freezes after partial fill, cancellation and withdrawal review', async () => {
      await order(25, 'PARTIALLY_FILLED');
      await order(40);
      await order(0, 'CANCELLED');
      const a = await withdrawal(10);
      const b = await withdrawal(20);
      await db.account.update({
        where: { id: accountId },
        data: { frozenBalance: 95 },
      });
      expect(await issues()).toEqual([]);
      for (const [id, status, remaining] of [
        [a.id, 'APPROVED', 85],
        [b.id, 'REJECTED', 65],
      ] as const) {
        await db.$transaction(async (tx) => {
          await tx.withdrawalRequest.update({
            where: { id },
            data: { status, frozenAmount: 0 },
          });
          await tx.account.update({
            where: { id: accountId },
            data: { frozenBalance: remaining },
          });
        });
        expect(await issues()).toEqual([]);
      }
      await db.account.update({
        where: { id: accountId },
        data: { frozenBalance: 66 },
      });
      expect(await issues()).toEqual([
        expect.objectContaining({
          details: {
            currency: 'INR',
            frozenBalance: 66,
            orderFrozen: 65,
            withdrawalFrozen: 0,
          },
        }),
      ]);
    });
  },
);
