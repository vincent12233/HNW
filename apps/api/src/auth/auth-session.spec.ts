import { UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { UserRole, UserStatus } from '../generated/prisma/enums';

describe('AuthService session lifecycle', () => {
  it('refreshes with a valid refresh token and rejects revoked versions', async () => {
    const user = {
      id: 'user-1',
      phone: '9876543210',
      role: UserRole.CLIENT,
      status: UserStatus.ACTIVE,
      authVersion: 2,
      deletedAt: null,
      fullName: 'Test',
      account: { id: 'acct-1' },
    };
    const auth = Object.create(AuthService.prototype) as AuthService;
    (auth as any).jwtService = {
      verifyAsync: jest.fn().mockResolvedValue({
        sub: 'user-1',
        purpose: 'REFRESH',
        version: 2,
      }),
      signAsync: jest
        .fn()
        .mockResolvedValueOnce('access-new')
        .mockResolvedValueOnce('refresh-new'),
    };
    (auth as any).prisma = {
      user: { findUnique: jest.fn().mockResolvedValue(user) },
    };

    const refreshed = await auth.refresh('refresh-old');
    expect(refreshed.accessToken).toBe('access-new');
    expect(refreshed.refreshToken).toBe('refresh-new');

    (auth as any).jwtService.verifyAsync.mockResolvedValue({
      sub: 'user-1',
      purpose: 'REFRESH',
      version: 1,
    });
    await expect(auth.refresh('refresh-old')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('revokes sessions by bumping authVersion', async () => {
    const update = jest.fn().mockResolvedValue({});
    const auth = Object.create(AuthService.prototype) as AuthService;
    (auth as any).prisma = { user: { update } };
    await auth.revokeSession('user-1');
    expect(update).toHaveBeenCalledWith({
      where: { id: 'user-1' },
      data: { authVersion: { increment: 1 } },
    });
  });
});
