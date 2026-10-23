import { TeamService } from './team.service';

describe('Team authenticator reset scope', () => {
  function fixture(actorRole: string, target: Record<string, unknown> | null) {
    const tx = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'actor',
          role: actorRole,
          status: 'ACTIVE',
        }),
        findFirst: jest.fn().mockResolvedValue(target),
        update: jest.fn(),
      },
      twoFactorCredential: { upsert: jest.fn() },
      auditLog: { create: jest.fn() },
    };
    const prisma = { ...tx, $transaction: (fn: any) => fn(tx) };
    return { service: new TeamService(prisma as any), tx };
  }

  it('lets a super administrator reset only a manager', async () => {
    const { service, tx } = fixture('ADMIN', {
      id: 'manager-1',
      role: 'MANAGER',
      fullName: 'Manager',
    });
    await expect(
      service.resetTwoFactor('admin-1', 'manager-1'),
    ).resolves.toMatchObject({
      reset: true,
      targetRole: 'MANAGER',
    });
    expect(tx.user.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'manager-1', role: 'MANAGER', deletedAt: null },
      }),
    );
    expect(tx.twoFactorCredential.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        update: expect.objectContaining({ enabled: false, secret: null }),
      }),
    );
    expect(tx.user.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { authVersion: { increment: 1 } } }),
    );
    expect(tx.auditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ action: 'STAFF_TWO_FACTOR_RESET' }),
      }),
    );
  });

  it('scopes a manager reset to a business user created by that manager', async () => {
    const { service, tx } = fixture('MANAGER', {
      id: 'business-1',
      role: 'BUSINESS',
      fullName: 'Business',
    });
    await service.resetTwoFactor('manager-1', 'business-1');
    expect(tx.user.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: 'business-1',
          role: 'BUSINESS',
          businessCreatorId: 'manager-1',
          deletedAt: null,
        },
      }),
    );
  });

  it.each(['ADMIN', 'MANAGER'])(
    'rejects a target outside the %s reset scope',
    async (role) => {
      const { service, tx } = fixture(role, null);
      await expect(service.resetTwoFactor('actor', 'outside')).rejects.toThrow(
        '不在当前验证器重置范围内',
      );
      expect(tx.twoFactorCredential.upsert).not.toHaveBeenCalled();
      expect(tx.user.update).not.toHaveBeenCalled();
    },
  );
});
