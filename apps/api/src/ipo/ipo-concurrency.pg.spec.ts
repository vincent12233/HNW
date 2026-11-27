import { randomUUID } from 'crypto';
import {
  auditPostgresEnabled,
  auditPrisma,
  withBlockedWriters,
} from '../testing/postgres-audit-fixture';
import { IpoService } from './ipo.service';

(auditPostgresEnabled ? describe : describe.skip)(
  'IPO application PostgreSQL concurrency',
  () => {
    const first = auditPrisma(),
      second = auditPrisma();
    const services = [new IpoService(first), new IpoService(second)];
    let userId: string, accountId: string, ipoId: string, instrumentId: string;
    beforeEach(async () => {
      userId = randomUUID();
      await first.user.create({
        data: {
          id: userId,
          email: `${userId}@test.local`,
          passwordHash: 'fixture',
          fullName: 'Fixture',
        },
      });
      accountId = (
        await first.account.create({
          data: {
            userId,
            accountNumber: randomUUID(),
            cashBalance: 1000,
            buyingPower: 1000,
          },
        })
      ).id;
      instrumentId = (
        await first.instrument.create({
          data: { symbol: randomUUID(), name: 'Fixture', exchange: 'NSE' },
        })
      ).id;
      ipoId = (
        await first.ipo.create({
          data: {
            instrumentId,
            symbol: randomUUID(),
            companyName: 'Fixture',
            exchange: 'NSE',
            issuePrice: 10,
            lotSize: 1,
            totalShares: 100,
            availableShares: 100,
            openDate: new Date(Date.now() - 86400000),
            closeDate: new Date(Date.now() + 86400000),
            status: 'PUBLISHED',
          },
        })
      ).id;
    });
    afterEach(async () => {
      await first.ipoApplication.deleteMany({ where: { ipoId } });
      await first.ipo.delete({ where: { id: ipoId } });
      await first.instrument.delete({ where: { id: instrumentId } });
      await first.account.delete({ where: { id: accountId } });
      await first.user.delete({ where: { id: userId } });
    });
    afterAll(async () => {
      await first.$disconnect();
      await second.$disconnect();
    });
    const apply = (index: number, key = randomUUID()) =>
      services[index].apply(userId, ipoId, key);
    const race = (keys: string[]) =>
      withBlockedWriters(
        'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
        [`ipo-apply:${accountId}:${ipoId}`],
        'pg_advisory_xact_lock',
        () => keys.map((key, index) => apply(index, key)),
      );
    it('only creates a fifth application when two independent requests race at four', async () => {
      for (let i = 0; i < 4; i++) await apply(0);
      const responses = await race([randomUUID(), randomUUID()]);
      expect(
        responses.filter((r) => (r as { canApply: boolean }).canApply),
      ).toHaveLength(1);
      expect(
        await first.ipoApplication.count({ where: { accountId, ipoId } }),
      ).toBe(5);
    });
    it('replays same-key concurrency and the original response after the limit or close', async () => {
      const key = randomUUID();
      const [a, b] = await race([key, key]);
      expect(a).toEqual(b);
      for (let i = 0; i < 4; i++) await apply(0);
      await first.ipo.update({
        where: { id: ipoId },
        data: { status: 'CLOSED' },
      });
      expect(await apply(1, key)).toEqual(a);
      expect(
        await first.ipoApplication.count({ where: { accountId, ipoId } }),
      ).toBe(5);
    });
    it('rolls creation back on response persistence failure without changing money or count', async () => {
      const broken = first.$extends({
        query: {
          ipoApplication: {
            update() {
              throw new Error('persistence failed');
            },
          },
        },
      });
      await expect(
        new IpoService(broken as typeof first).apply(
          userId,
          ipoId,
          randomUUID(),
        ),
      ).rejects.toThrow('persistence failed');
      expect(
        await first.ipoApplication.count({ where: { accountId, ipoId } }),
      ).toBe(0);
      const account = await first.account.findUniqueOrThrow({
        where: { id: accountId },
      });
      expect(account.cashBalance.toString()).toBe('1000');
      expect(account.frozenBalance.toString()).toBe('0');
    });
    it('preserves historical excess while blocking further applications', async () => {
      await first.ipoApplication.createMany({
        data: Array.from({ length: 6 }, () => ({
          accountId,
          ipoId,
          quantity: 1,
          amount: 10,
        })),
      });
      expect(await apply(0)).toMatchObject({
        canApply: false,
        appliedCount: 6,
      });
      expect(
        await first.ipoApplication.count({ where: { accountId, ipoId } }),
      ).toBe(6);
    });
    it('does not block another account or IPO behind one account/IPO lock', async () => {
      const otherUser = await first.user.create({
        data: {
          email: `${randomUUID()}@test.local`,
          fullName: 'Other',
          passwordHash: 'fixture',
        },
      });
      const otherAccount = await first.account.create({
        data: { userId: otherUser.id, accountNumber: randomUUID() },
      });
      const ipo = await first.ipo.findUniqueOrThrow({ where: { id: ipoId } });
      const otherIpo = await first.ipo.create({
        data: { ...ipo, id: randomUUID(), symbol: randomUUID() },
      });
      try {
        await withBlockedWriters(
          'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
          [`ipo-apply:${accountId}:${ipoId}`],
          'pg_advisory_xact_lock',
          () => [apply(0)],
          async () => {
            // These must finish before the first account/IPO lock is released.
            await expect(
              services[1].apply(otherUser.id, ipoId, randomUUID()),
            ).resolves.toMatchObject({ canApply: true });
            await expect(
              services[1].apply(userId, otherIpo.id, randomUUID()),
            ).resolves.toMatchObject({ canApply: true });
          },
        );
      } finally {
        await first.ipoApplication.deleteMany({
          where: {
            OR: [{ accountId: otherAccount.id }, { ipoId: otherIpo.id }],
          },
        });
        await first.ipo.delete({ where: { id: otherIpo.id } });
        await first.account.delete({ where: { id: otherAccount.id } });
        await first.user.delete({ where: { id: otherUser.id } });
      }
    });
  },
);
