import { randomUUID } from 'crypto';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import {
  auditPostgresEnabled,
  auditPrisma,
  withBlockedWriters,
} from '../testing/postgres-audit-fixture';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { UsersService } from '../users/users.service';
import { ClientExperienceService } from '../client-experience/client-experience.service';

(auditPostgresEnabled ? describe : describe.skip)(
  'Device sessions PostgreSQL and real JWT',
  () => {
    const first = auditPrisma(),
      second = auditPrisma();
    const jwt = new JwtService({ secret: process.env.JWT_SECRET });
    const config = new ConfigService({ JWT_SECRET: process.env.JWT_SECRET });
    const twoFactor = {
      status: async () => ({ enabled: false }),
      verifyLogin: async () => {},
    };
    const auth = [first, second].map(
      (db) =>
        new AuthService(
          new UsersService(db),
          jwt,
          db,
          config,
          twoFactor as never,
        ),
    );
    const strategy = [first, second].map((db) => new JwtStrategy(config, db));
    const experience = new ClientExperienceService(second);
    let userId: string, phone: string;
    let tokens: Awaited<ReturnType<AuthService['login']>>[];
    let devices: string[];
    const check = (index: number, token: string) =>
      strategy[index].validate(jwt.verify(token));
    beforeEach(async () => {
      userId = randomUUID();
      phone = `984${String(Date.now()).slice(-7)}`;
      await first.user.create({
        data: {
          id: userId,
          phone,
          email: `${userId}@test.local`,
          fullName: 'Fixture',
          passwordHash: await bcrypt.hash('fixture-password', 4),
        },
      });
      await first.account.create({
        data: { userId, accountNumber: randomUUID() },
      });
      tokens = await Promise.all(
        auth.map((service, index) =>
          service.login(
            { phone, password: 'fixture-password' },
            { userAgent: `Device ${index}` },
          ),
        ),
      );
      devices = tokens.map((t) => jwt.verify(t.accessToken).sid as string);
    });
    afterEach(async () => {
      await first.$executeRaw`DELETE FROM consumed_refresh_tokens WHERE "userId" = ${userId}`;
      await first.account.delete({ where: { userId } });
      await first.loginAudit.deleteMany({ where: { userId } });
      await first.userDevice.deleteMany({ where: { userId } });
      await first.user.delete({ where: { id: userId } });
    });
    afterAll(async () => {
      await first.$disconnect();
      await second.$disconnect();
    });
    it('revokes access, refresh and biometric on one device across instances, leaving the other usable', async () => {
      const biometric = await Promise.all(
        devices.map((id, i) => auth[i].createBiometricToken(userId, id)),
      );
      await check(0, tokens[0].accessToken); // warm the other instance: no positive auth cache is allowed.
      expect(await experience.revokeDevice(userId, devices[0])).toEqual({
        revoked: true,
      });
      expect(await experience.revokeDevice(userId, devices[0])).toEqual({
        revoked: true,
      });
      await expect(check(0, tokens[0].accessToken)).rejects.toMatchObject({
        status: 401,
      });
      await expect(
        auth[0].refresh(tokens[0].refreshToken),
      ).rejects.toMatchObject({ status: 401 });
      await expect(
        auth[0].biometricLogin(biometric[0].biometricToken),
      ).rejects.toMatchObject({ status: 401 });
      await expect(check(1, tokens[1].accessToken)).resolves.toMatchObject({
        sessionId: devices[1],
      });
      await expect(
        auth[1].refresh(tokens[1].refreshToken),
      ).resolves.toHaveProperty('accessToken');
      await expect(
        auth[1].biometricLogin(biometric[1].biometricToken),
      ).resolves.toHaveProperty('accessToken');
      await expect(
        experience.registerDevice(
          userId,
          { deviceName: 'Cannot revive' },
          devices[0],
        ),
      ).rejects.toMatchObject({ status: 401 });
    });
    it('serializes refresh and revocation; any issued replacement is unusable after revocation commits', async () => {
      const results = await withBlockedWriters(
        'SELECT id FROM user_devices WHERE id=$1 FOR UPDATE',
        [devices[0]],
        'user_devices',
        () =>
          [
            auth[0]
              .refresh(tokens[0].refreshToken)
              .catch((error) => ({ error })),
            experience.revokeDevice(userId, devices[0]),
          ] as Promise<unknown>[],
      );
      const refreshed = results[0] as {
        accessToken?: string;
        refreshToken?: string;
        error?: { status: number };
      };
      if (refreshed.accessToken) {
        await expect(check(1, refreshed.accessToken)).rejects.toMatchObject({
          status: 401,
        });
        await expect(
          auth[1].refresh(refreshed.refreshToken!),
        ).rejects.toMatchObject({ status: 401 });
      } else expect(refreshed.error).toMatchObject({ status: 401 });
    });
    it('rejects unbound historical credentials and prevents client-supplied session impersonation', async () => {
      const user = await first.user.findUniqueOrThrow({
        where: { id: userId },
      });
      for (const purpose of [undefined, 'REFRESH', 'BIOMETRIC_LOGIN']) {
        const old = jwt.sign({
          sub: userId,
          version: user.authVersion,
          ...(purpose ? { purpose } : {}),
        });
        const result =
          purpose === 'REFRESH'
            ? auth[0].refresh(old)
            : purpose === 'BIOMETRIC_LOGIN'
              ? auth[0].biometricLogin(old)
              : check(0, old);
        await expect(result).rejects.toMatchObject({ status: 401 });
      }
      const device = await experience.registerDevice(
        userId,
        { id: devices[1], deviceName: 'Display label' },
        devices[0],
      );
      expect(device.id).toBe(devices[0]);
      expect(
        (
          await first.userDevice.findUniqueOrThrow({
            where: { id: devices[1] },
          })
        ).deviceName,
      ).toBe('Device 1');
    });
  },
);
