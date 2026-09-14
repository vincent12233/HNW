import { JwtService } from '@nestjs/jwt';

import { AuthService } from './auth.service';
import { UserRole } from '../generated/prisma/enums';

describe('AuthService access token TTL', () => {
  it('issues 1h tokens for clients and 7d tokens for staff', async () => {
    const signAsync = jest.fn(async (_payload: unknown, options?: { expiresIn?: string }) => {
      return `token:${options?.expiresIn ?? 'default'}`;
    });
    const auth = new AuthService(
      {} as never,
      { signAsync } as unknown as JwtService,
      {} as never,
      {} as never,
      {} as never,
    );

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

    expect(clientToken).toBe('token:1h');
    expect(financeToken).toBe('token:7d');
    expect((auth as any).accessTokenExpiresIn(UserRole.CLIENT)).toBe(3600);
    expect((auth as any).accessTokenExpiresIn(UserRole.FINANCE)).toBe(7 * 24 * 60 * 60);
  });
});
