import * as OTPAuth from 'otpauth';
import * as bcrypt from 'bcrypt';
import { TwoFactorService } from './two-factor.service';

describe('Two factor authentication', () => {
  let row: any, user: any, prisma: any, service: TwoFactorService;
  beforeEach(async () => {
    row = {
      userId: 'client',
      enabled: false,
      lastStep: -1,
      attempts: 0,
      lockedUntil: null,
      recoveryHashes: [],
    };
    user = {
      id: 'client',
      phone: '+919999999999',
      passwordHash: await bcrypt.hash('test-password', 4),
      authVersion: 0,
    };
    const tx = {
      $queryRaw: jest.fn().mockResolvedValue([]),
      twoFactorCredential: {
        upsert: jest.fn().mockResolvedValue(row),
        findUnique: jest.fn(async () => row),
        findUniqueOrThrow: jest.fn(async () => row),
        update: jest.fn(async ({ data }: any) => Object.assign(row, data)),
      },
      user: {
        findUniqueOrThrow: jest.fn(async () => user),
        update: jest.fn(async () => {
          user.authVersion++;
          return user;
        }),
      },
    };
    prisma = { ...tx, $transaction: (fn: any) => fn(tx) };
    service = new TwoFactorService(prisma, {
      get: (key: string) =>
        key === 'TWO_FACTOR_ENCRYPTION_KEY'
          ? 'unit-test-two-factor-secret-32-characters'
          : 'unit-test-jwt-secret-32-characters',
    } as any);
  });
  async function enable() {
    const setup = await service.setup('client', 'test-password');
    const code = new OTPAuth.TOTP({
      secret: OTPAuth.Secret.fromBase32(setup.secret),
    }).generate();
    const result = await service.confirm('client', code);
    return { setup, code, result };
  }
  it('encrypts secrets and only enables after a valid confirmation', async () => {
    const setup = await service.setup('client', 'test-password');
    expect(row.pendingSecret).not.toContain(setup.secret);
    expect(row.enabled).toBe(false);
    await expect(service.confirm('client', 'not-a-code')).rejects.toThrow();
    expect(row.attempts).toBe(1);
    const code = new OTPAuth.TOTP({
      secret: OTPAuth.Secret.fromBase32(setup.secret),
    }).generate();
    const result = await service.confirm('client', code);
    expect(result.recoveryCodes).toHaveLength(8);
    expect(row.recoveryHashes).not.toContain(result.recoveryCodes[0]);
    expect(row.pendingSecret).toBeNull();
    expect(user.authVersion).toBe(1);
  });
  it('requires a second factor, prevents replay and consumes recovery codes once', async () => {
    const { code, result } = await enable();
    await expect(service.verifyLogin('client')).rejects.toThrow(
      'Enter your authenticator',
    );
    await expect(service.verifyLogin('client', code)).rejects.toThrow(
      'already used',
    );
    await service.verifyLogin('client', result.recoveryCodes[0]);
    expect(row.recoveryHashes).toHaveLength(7);
    await expect(
      service.verifyLogin('client', result.recoveryCodes[0]),
    ).rejects.toThrow('already used');
  });
  it('locks repeated wrong passwords and keeps the failure counter committed', async () => {
    for (let i = 0; i < 5; i++)
      await expect(service.setup('client', 'wrong')).rejects.toThrow();
    expect(row.attempts).toBe(5);
    await expect(service.setup('client', 'test-password')).rejects.toThrow(
      '15 minutes',
    );
  });
  it('expires unfinished enrollment', async () => {
    await service.setup('client', 'test-password');
    row.pendingExpiresAt = new Date(0);
    await expect(service.confirm('client', '123456')).rejects.toThrow(
      'setup again',
    );
  });
  it('disables only with password and a second factor and revokes sessions', async () => {
    const { result } = await enable();
    await expect(
      service.disable('client', 'wrong', result.recoveryCodes[0]),
    ).rejects.toThrow();
    await service.disable('client', 'test-password', result.recoveryCodes[0]);
    expect(row.enabled).toBe(false);
    expect(row.secret).toBeNull();
    expect(row.recoveryHashes).toHaveLength(0);
    expect(user.authVersion).toBe(2);
  });
});
