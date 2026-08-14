import { ExecutionContext, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../prisma/prisma.service';
import { RolesGuard } from './roles.guard';

describe('RolesGuard', () => {
  const request: any = { user: { userId: 'staff-1', role: 'CLIENT' } };
  const context = {
    getHandler: jest.fn(),
    getClass: jest.fn(),
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
  const reflector = { getAllAndOverride: jest.fn() } as unknown as Reflector;
  const prisma = {
    user: { findUnique: jest.fn() },
  } as unknown as PrismaService;
  const guard = new RolesGuard(reflector, prisma);

  beforeEach(() => {
    jest.clearAllMocks();
    request.user = { userId: 'staff-1', role: 'CLIENT' };
  });

  it('allows routes without role metadata', async () => {
    (reflector.getAllAndOverride as jest.Mock).mockReturnValue(undefined);
    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect((prisma.user.findUnique as jest.Mock)).not.toHaveBeenCalled();
  });

  it('rejects requests without an authenticated user', async () => {
    (reflector.getAllAndOverride as jest.Mock).mockReturnValue(['ADMIN']);
    request.user = undefined;
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects inactive accounts even when the token role looks valid', async () => {
    (reflector.getAllAndOverride as jest.Mock).mockReturnValue(['ADMIN']);
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({ role: 'ADMIN', status: 'SUSPENDED' });
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects a role that is not permitted by the endpoint', async () => {
    (reflector.getAllAndOverride as jest.Mock).mockReturnValue(['FINANCE']);
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({ role: 'BUSINESS', status: 'ACTIVE' });
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('uses the current database role and allows a permitted active user', async () => {
    (reflector.getAllAndOverride as jest.Mock).mockReturnValue(['FINANCE']);
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({ role: 'FINANCE', status: 'ACTIVE' });
    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.user.role).toBe('FINANCE');
  });
});
