import { AdminUsersService } from './admin-users.service';

describe('Admin user status retains team relations', () => {
  it('disables a manager without clearing businessCreatorId or assignedBusinessId', async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'mgr-1',
          role: 'MANAGER',
          status: 'ACTIVE',
        }),
        count: jest
          .fn()
          .mockResolvedValueOnce(3)
          .mockResolvedValueOnce(0),
        update: jest.fn().mockResolvedValue({
          id: 'mgr-1',
          fullName: 'Manager',
          phone: null,
          role: 'MANAGER',
          status: 'DISABLED',
          businessCreatorId: 'admin-1',
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      },
    };
    const audit = { createLog: jest.fn() };
    const service = new AdminUsersService(prisma as never, audit as never);
    const result = await service.updateStatus('admin-1', 'mgr-1', {
      status: 'DISABLED',
    });
    expect(prisma.user.update.mock.calls[0][0].data).toEqual({
      status: 'DISABLED',
    });
    expect(result.relationsRetained).toBe(true);
    expect(result.remainingBusinessCount).toBe(3);
    expect(result.assignedBusinessIdUnchanged).toBe(true);
    expect(audit.createLog.mock.calls[0][0].metadata.relationsRetained).toBe(
      true,
    );
  });
});
