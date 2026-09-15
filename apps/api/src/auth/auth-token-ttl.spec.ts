import { JwtService } from '@nestjs/jwt';

import { AuthService } from './auth.service';
import { UserRole } from '../generated/prisma/enums';

describe('AuthService access token TTL', () => {
  it('issues long-lived tokens for clients and staff until logout', async () => {
    const signAsync = jest.fn(
      async (_payload: unknown, options?: { expiresIn?: string }) =>
        `token:${options?.expiresIn ?? 'default'}`,
    );
    const auth = Object.create(AuthService.prototype) as AuthService;
    (auth as any).jwtService = { signAsync } as unknown as JwtService;

    const clientToken = await (auth as any).issueAccessToken({
      id: 'c1',
      phone: '9876543210',
      role: UserRole.CLIENT,
      authVersion: 1,
    });
    const financeToken = await (auth as any).issueAccessToken({
      id: 'f1',
      phone: null,
      role: UserRole.FINANCE,
      authVersion: 1,
    });

    expect(clientToken).toBe('token:365d');
    expect(financeToken).toBe('token:365d');
    expect((auth as any).accessTokenExpiresIn(UserRole.CLIENT)).toBe(
      365 * 24 * 60 * 60,
    );
    expect((auth as any).accessTokenExpiresIn(UserRole.FINANCE)).toBe(
      365 * 24 * 60 * 60,
    );
  });
});
