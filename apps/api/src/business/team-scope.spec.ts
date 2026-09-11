import { TeamService } from './team.service';

describe('Team editing scope', () => {
  it('requires an owned business account for manager edits', async () => {
    const prisma = { user: {
      findUnique: jest.fn().mockResolvedValue({ id: 'manager', role: 'MANAGER', status: 'ACTIVE' }),
      findFirst: jest.fn().mockResolvedValue(null),
    } };
    const service = new TeamService(prisma as any);
    await expect(service.business('manager', 'other-business')).rejects.toThrow('not found in your team');
    expect(prisma.user.findFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'other-business', role: 'BUSINESS', businessCreatorId: 'manager', deletedAt: null },
    }));
    prisma.user.findFirst.mockResolvedValue({ id: 'own-business' } as never);
    await expect(service.business('manager', 'own-business')).resolves.toBe('own-business');
  });
  it.each(['BUSINESS', 'FINANCE', 'SUPPORT', 'CLIENT'])(
    'rejects %s from team management', async role => {
      const service = new TeamService({ user: { findUnique: jest.fn().mockResolvedValue({ role, status: 'ACTIVE' }) } } as any);
      await expect(service.business('actor', 'business')).rejects.toThrow();
    },
  );
});
