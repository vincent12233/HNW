import {
  ExecutionContext,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';

describe('Client trading RBAC', () => {
  const staffRoles = [
    UserRole.ADMIN,
    UserRole.MANAGER,
    UserRole.BUSINESS,
    UserRole.FINANCE,
    UserRole.SUPPORT,
  ] as const;

  function createGuard(role: string | null, status = 'ACTIVE') {
    const request: any = role
      ? { user: { userId: 'user-1', role } }
      : { user: undefined };
    const context = {
      getHandler: jest.fn(),
      getClass: jest.fn(),
      switchToHttp: () => ({ getRequest: () => request }),
    } as unknown as ExecutionContext;
    const reflector = {
      getAllAndOverride: jest.fn().mockReturnValue([UserRole.CLIENT]),
    } as unknown as Reflector;
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(
          role
            ? {
                role,
                status,
              }
            : null,
        ),
      },
    } as any;
    return {
      guard: new RolesGuard(reflector, prisma),
      context,
      request,
    };
  }

  it('allows CLIENT to access client trading endpoints', async () => {
    const { guard, context } = createGuard(UserRole.CLIENT);
    await expect(guard.canActivate(context)).resolves.toBe(true);
  });

  it.each(staffRoles)('forbids %s from client trading endpoints', async (role) => {
    const { guard, context } = createGuard(role);
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('forbids unauthenticated callers', async () => {
    const { guard, context } = createGuard(null);
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
