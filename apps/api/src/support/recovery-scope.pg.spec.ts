import { randomUUID } from 'crypto';
import {
  auditPostgresEnabled,
  auditPrisma,
  withBlockedWriters,
} from '../testing/postgres-audit-fixture';
import { AccountRecoveryService } from './account-recovery.service';
import { RecoveryActor } from './recovery-scope';

(auditPostgresEnabled ? describe : describe.skip)(
  'Recovery customer scope PostgreSQL',
  () => {
    const db = auditPrisma();
    const service = new AccountRecoveryService(db);
    const users: string[] = [];
    const sessions: string[] = [];
    let support: RecoveryActor;
    let admin: RecoveryActor;
    let customer: string;
    let other: string;
    let inviteId: string;
    let own: { id: string; token: string };
    let outside: { id: string; token: string };
    let ordinary: { id: string; token: string };
    const previousCode = process.env.ADMIN_FIXED_INVITE_CODE;
    beforeAll(async () => {
      process.env.ADMIN_FIXED_INVITE_CODE =
        `AUDIT${randomUUID()}`.toUpperCase();
      async function user(
        role: 'SUPPORT' | 'ADMIN' | 'CLIENT',
        phone?: string,
        assignedBusinessId?: string,
        usedInviteCodeId?: string,
      ) {
        const id = randomUUID();
        users.push(id);
        await db.user.create({
          data: {
            id,
            role,
            phone,
            assignedBusinessId,
            usedInviteCodeId,
            email: `${id}@test.local`,
            passwordHash: 'fixture',
            fullName: 'Fixture',
          },
        });
        return id;
      }
      support = { userId: await user('SUPPORT'), role: 'SUPPORT' };
      admin = { userId: await user('ADMIN'), role: 'ADMIN' };
      other = await user('SUPPORT');
      const profile = await db.businessProfile.create({
        data: { userId: support.userId, employeeNo: randomUUID() },
      });
      inviteId = (
        await db.inviteCode.create({
          data: {
            code: process.env.ADMIN_FIXED_INVITE_CODE,
            businessProfileId: profile.id,
          },
        })
      ).id;
      const suffix = String(Date.now()).slice(-7);
      const phones = [`981${suffix}`, `982${suffix}`, `983${suffix}`];
      customer = await user('CLIENT', phones[0], support.userId, inviteId);
      await user('CLIENT', phones[1], other, inviteId);
      await user('CLIENT', phones[2]);
      own = await service.open(phones[0]);
      outside = await service.open(phones[1]);
      ordinary = await service.open(phones[2]);
      sessions.push(own.id, outside.id, ordinary.id);
    });
    afterAll(async () => {
      await db.$executeRaw`DELETE FROM support_interaction_references WHERE "actorId" = ${support.userId} OR "actorId" = ${admin.userId}`;
      for (const id of sessions)
        await db.$executeRaw`DELETE FROM account_recovery_sessions WHERE id = ${id}::uuid`;
      await db.auditLog.deleteMany({
        where: {
          OR: [{ actorId: { in: users } }, { resourceId: { in: sessions } }],
        },
      });
      await db.notification.deleteMany({ where: { userId: { in: users } } });
      await db.user.deleteMany({
        where: { id: { in: users }, role: 'CLIENT' },
      });
      await db.user.deleteMany({ where: { id: { in: users } } });
      await db.$disconnect();
      if (previousCode === undefined)
        delete process.env.ADMIN_FIXED_INVITE_CODE;
      else process.env.ADMIN_FIXED_INVITE_CODE = previousCode;
    });
    it('filters lists and blocks every employee operation outside persisted customer scope', async () => {
      expect(
        ((await service.list(support)) as { id: string }[]).map((r) => r.id),
      ).toEqual([own.id]);
      expect(
        ((await service.list(admin)) as { id: string }[]).map((r) => r.id),
      ).toEqual(expect.arrayContaining(sessions));
      await service.staffSend(own.id, 'Authorized message', support);
      expect(await service.staffMessages(own.id, support)).toHaveLength(1);
      for (const session of [outside, ordinary]) {
        await expect(
          service.staffMessages(session.id, support),
        ).rejects.toMatchObject({ status: 404 });
        await expect(
          service.staffSend(session.id, 'Forbidden', support),
        ).rejects.toMatchObject({ status: 404 });
        await expect(
          service.issue(session.id, support, true, 'verified-fixture'),
        ).rejects.toMatchObject({ status: 404 });
        expect(await service.staffMessages(session.id, admin)).toHaveLength(0);
      }
      const rows = await db.$queryRaw<
        { codeHash: string | null }[]
      >`SELECT "codeHash" FROM account_recovery_sessions WHERE id = ${outside.id}::uuid`;
      expect(rows[0].codeHash).toBeNull();
    });
    it('rejects a previously issued code and new staff actions after transfer; ADMIN remains authorized', async () => {
      const result = await service.issue(
        own.id,
        support,
        true,
        `fixture-${randomUUID()}`,
      );
      await db.user.update({
        where: { id: customer },
        data: { assignedBusinessId: other },
      });
      await expect(
        service.reset(own.token, result.code, 'NewPassword123'),
      ).rejects.toMatchObject({ status: 400 });
      expect(
        (await db.user.findUniqueOrThrow({ where: { id: customer } }))
          .passwordHash,
      ).toBe('fixture');
      await expect(
        service.issue(own.id, support, true, 'fixture-transfer'),
      ).rejects.toMatchObject({ status: 404 });
      await expect(
        service.staffSend(own.id, 'Forbidden', support),
      ).rejects.toMatchObject({ status: 404 });
      expect((await service.list(support)) as unknown[]).toHaveLength(0);
      await service.staffSend(own.id, 'Admin allowed', admin);
      await db.$executeRaw`UPDATE account_recovery_sessions SET "codeExpiresAt" = CURRENT_TIMESTAMP - INTERVAL '1 minute' WHERE id = ${own.id}::uuid`;
      const adminCode = await service.issue(
        own.id,
        admin,
        true,
        `fixture-${randomUUID()}`,
      );
      expect(
        await service.reset(own.token, adminCode.code, 'NewPassword123'),
      ).toEqual({ changed: true });
    });
    it('rechecks ownership after a concurrent transfer commits under the customer row lock', async () => {
      await db.user.update({
        where: { id: customer },
        data: { assignedBusinessId: support.userId },
      });
      await db.$executeRaw`UPDATE account_recovery_sessions SET status = 'OPEN', "codeExpiresAt" = NULL WHERE id = ${own.id}::uuid`;
      // The holder changes ownership before releasing its row lock, so the waiting issuer sees the committed transfer.
      const results = await withBlockedWriters(
        'UPDATE users SET "assignedBusinessId"=$2 WHERE id=$1',
        [customer, other],
        'FOR UPDATE OF customer',
        () => [
          service.issue(own.id, support, true, 'fixture-race').catch((e) => e),
        ],
      );
      expect(results[0]).toMatchObject({ status: 404 });
    });
  },
);
