import { UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { UserRole, UserStatus } from '../generated/prisma/enums';

describe('AuthService enterprise session matrix', () => {
  const user = {
    id: 'client-1',
    phone: '9876543210',
    role: UserRole.CLIENT,
    status: UserStatus.ACTIVE,
    authVersion: 4,
    deletedAt: null,
    fullName: 'Client',
    account: { id: 'account-1' },
  };

  it('issues a unique token id for refresh tokens created in the same second', async () => {
    const auth = Object.create(AuthService.prototype) as AuthService;
    const payloads: Array<{ jti?: string }> = [];
    (auth as any).jwtService = {
      signAsync: jest.fn(async (payload: { jti?: string }) => {
        payloads.push(payload);
        return 'signed';
      }),
    };

    await (auth as any).issueRefreshToken(user);
    await (auth as any).issueRefreshToken(user);

    expect(payloads[0].jti).toMatch(/^[0-9a-f]{32}$/);
    expect(payloads[1].jti).toMatch(/^[0-9a-f]{32}$/);
    expect(payloads[0].jti).not.toBe(payloads[1].jti);
  });

  it('accepts a refresh token once and rejects replay without changing login credentials', async () => {
    const consumed = new Set<string>();
    const tx = {
      $executeRaw: jest.fn(
        async (parts: TemplateStringsArray, tokenHash: string) => {
          if (consumed.has(tokenHash)) {
            const duplicate = new Error('duplicate') as Error & {
              code: string;
            };
            duplicate.code = '23505';
            throw duplicate;
          }
          consumed.add(tokenHash);
          return 1;
        },
      ),
      user: { findUnique: jest.fn().mockResolvedValue(user) },
    };
    const auth = Object.create(AuthService.prototype) as AuthService;
    (auth as any).prisma = { $transaction: (callback: any) => callback(tx) };
    (auth as any).jwtService = {
      verifyAsync: jest
        .fn()
        .mockResolvedValue({
          sub: user.id,
          purpose: 'REFRESH',
          version: 4,
          exp: 2000000000,
        }),
      signAsync: jest
        .fn()
        .mockResolvedValueOnce('access-new')
        .mockResolvedValueOnce('refresh-new'),
    };

    await expect(auth.refresh('refresh-old')).resolves.toMatchObject({
      accessToken: 'access-new',
    });
    await expect(auth.refresh('refresh-old')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(tx.$executeRaw).toHaveBeenCalledTimes(2);
  });

  it('rejects disabled, deleted, and version-revoked users before issuing replacement tokens', async () => {
    for (const blocked of [
      { ...user, status: UserStatus.SUSPENDED },
      { ...user, deletedAt: new Date() },
      { ...user, authVersion: 5 },
    ]) {
      const auth = Object.create(AuthService.prototype) as AuthService;
      (auth as any).prisma = {
        $transaction: (callback: any) =>
          callback({
            $executeRaw: jest.fn().mockResolvedValue(1),
            user: { findUnique: jest.fn().mockResolvedValue(blocked) },
          }),
      };
      (auth as any).jwtService = {
        verifyAsync: jest
          .fn()
          .mockResolvedValue({
            sub: user.id,
            purpose: 'REFRESH',
            version: 4,
            exp: 2000000000,
          }),
        signAsync: jest.fn(),
      };
      await expect(auth.refresh('refresh-old')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      expect((auth as any).jwtService.signAsync).not.toHaveBeenCalled();
    }
  });
});
