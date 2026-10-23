import { UnauthorizedException } from '@nestjs/common';
import type { ExecutionContext } from '@nestjs/common';
import { StaffTwoFactorSetupGuard } from './staff-two-factor-setup.guard';

describe('StaffTwoFactorSetupGuard', () => {
  const request = { headers: { authorization: 'Bearer setup-token' } } as any;
  const context = {
    switchToHttp: () => ({ getRequest: () => request }),
  } as ExecutionContext;

  function fixture(overrides: Record<string, unknown> = {}) {
    const jwt = {
      verifyAsync: jest.fn().mockResolvedValue({
        sub: 'manager-1',
        role: 'MANAGER',
        version: 3,
        purpose: 'STAFF_2FA_SETUP',
      }),
    };
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'manager-1',
          role: 'MANAGER',
          status: 'ACTIVE',
          authVersion: 3,
          businessProfile: { isActive: true },
          twoFactor: { enabled: false },
          ...overrides,
        }),
      },
    };
    return {
      guard: new StaffTwoFactorSetupGuard(jwt as any, prisma as any),
      jwt,
    };
  }

  it('accepts only an active unbound staff account with the current auth version', async () => {
    const { guard } = fixture();
    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.user).toEqual({ userId: 'manager-1', role: 'MANAGER' });
  });

  it.each([
    { authVersion: 4 },
    { status: 'DISABLED' },
    { twoFactor: { enabled: true } },
    { role: 'CLIENT' },
  ])('rejects revoked or non-staff setup access: %o', async (overrides) => {
    const { guard } = fixture(overrides);
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('rejects a token issued for another purpose', async () => {
    const { guard, jwt } = fixture();
    jwt.verifyAsync.mockResolvedValue({
      sub: 'manager-1',
      role: 'MANAGER',
      version: 3,
      purpose: 'KYC_ONBOARDING',
    });
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
