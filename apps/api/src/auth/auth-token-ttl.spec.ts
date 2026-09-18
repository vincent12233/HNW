import { JwtService } from '@nestjs/jwt';

import { AuthService } from './auth.service';
import { UserRole } from '../generated/prisma/enums';

describe('AuthService access token TTL', () => {
  it('issues short-lived access tokens with refresh tokens', async () => {
    const signAsync = jest.fn(
      async (payload: { purpose?: string }, options?: { expiresIn?: string }) =>
        `token:${payload.purpose ?? 'access'}:${options?.expiresIn ?? 'default'}`,
    );
    const auth = Object.create(AuthService.prototype) as AuthService;
    (auth as any).jwtService = { signAsync } as unknown as JwtService;

    const tokens = await (auth as any).issueSessionTokens({
      id: 'c1',
      phone: '9876543210',
      role: UserRole.CLIENT,
      authVersion: 1,
    });

    expect(tokens.accessToken).toBe('token:access:24h');
    expect(tokens.refreshToken).toBe('token:REFRESH:30d');
    expect(tokens.expiresIn).toBe(24 * 60 * 60);
    expect(tokens.refreshExpiresIn).toBe(30 * 24 * 60 * 60);
  });
});
