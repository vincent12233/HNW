import { TeamService } from './team.service';

describe('Team staff deletion', () => {
  function setup(
    role: string,
    target: any = { id: 'target', role: 'BUSINESS' },
    dependents = 0,
  ) {
    const tx = {
      user: {
        findFirst: jest.fn().mockResolvedValue(target),
        count: jest.fn().mockResolvedValue(dependents),
        update: jest.fn(),
      },
      businessProfile: { updateMany: jest.fn() },
      inviteCode: { updateMany: jest.fn() },
      auditLog: { create: jest.fn() },
    };
    const service = new TeamService({
      user: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ id: 'actor', role, status: 'ACTIVE' }),
      },
      $transaction: (fn: any) => fn(tx),
    } as any);
    return { service, tx };
  }
  it('restricts managers to their own business users and revokes access', async () => {
    const { service, tx } = setup('MANAGER');
    await service.remove('actor', 'target');
    expect(tx.user.findFirst.mock.calls[0][0].where).toMatchObject({
      role: 'BUSINESS',
      businessCreatorId: 'actor',
      deletedAt: null,
    });
    expect(tx.user.update.mock.calls[0][0].data).toMatchObject({
      status: 'DISABLED',
      authVersion: { increment: 1 },
      deletedAt: expect.any(Date),
    });
    expect(tx.inviteCode.updateMany).toHaveBeenCalled();
    expect(tx.auditLog.create).toHaveBeenCalled();
  });
  it('restricts super administrators to manager accounts', async () => {
    const { service, tx } = setup('ADMIN', { id: 'target', role: 'MANAGER' });
    await service.remove('actor', 'target');
    expect(tx.user.findFirst.mock.calls[0][0].where.role).toBe('MANAGER');
  });
  it('rejects out-of-scope accounts without mutations', async () => {
    const { service, tx } = setup('MANAGER', null);
    await expect(service.remove('actor', 'target')).rejects.toThrow();
    expect(tx.user.update).not.toHaveBeenCalled();
  });
  it('preserves accounts with assigned customers or staff', async () => {
    const { service, tx } = setup('MANAGER', undefined, 1);
    await expect(service.remove('actor', 'target')).rejects.toThrow('转移');
    expect(tx.user.update).not.toHaveBeenCalled();
  });
});
