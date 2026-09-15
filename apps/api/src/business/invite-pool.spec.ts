import { validate } from 'class-validator';
import { BusinessController } from './business.controller';
import { BusinessService } from './business.service';
import { TeamService } from './team.service';
import { InvitePoolDto } from './team.dto';

describe('Invite pool ownership', () => {
  it.each([0, 101, 1.5, '10', null])(
    'rejects invalid count %s',
    async (count) => {
      expect(
        (await validate(Object.assign(new InvitePoolDto(), { count }))).length,
      ).toBeGreaterThan(0);
    },
  );
  it('only allows managers to generate pools and create business accounts', () => {
    for (const method of ['generateInviteCodes', 'createBusiness'] as const) {
      expect(
        Reflect.getMetadata('roles', BusinessController.prototype[method]),
      ).toEqual(['MANAGER']);
    }
  });
  it('does not generate codes for another manager team', async () => {
    const business = { generateInviteCodes: jest.fn() };
    const team = {
      business: jest.fn().mockRejectedValue(new Error('outside team')),
    };
    const controller = new BusinessController(business as any, team as any);
    await expect(
      controller.generateInviteCodes(
        { user: { userId: 'manager' } },
        'foreign',
        { count: 10 },
      ),
    ).rejects.toThrow('outside team');
    expect(business.generateInviteCodes).not.toHaveBeenCalled();
  });
  it('generates an owned pool with an audit and returns only the count', async () => {
    const business = {
      generateInviteCodes: jest
        .fn()
        .mockResolvedValue([{ code: 'A' }, { code: 'B' }]),
    };
    const team = {
      business: jest.fn().mockResolvedValue('own'),
      audit: jest.fn(),
    };
    const controller = new BusinessController(business as any, team as any);
    await expect(
      controller.generateInviteCodes({ user: { userId: 'manager' } }, 'own', {
        count: 2,
      }),
    ).resolves.toEqual({ count: 2 });
    expect(team.business).toHaveBeenCalledWith('manager', 'own');
    expect(team.audit).toHaveBeenCalledWith(
      'manager',
      'own',
      'MANAGER_INVITE_POOL_GENERATED',
    );
  });
  it('refresh selects one valid owned code without consuming or disabling it', async () => {
    const prisma = {
      inviteCode: {
        findFirst: jest.fn().mockResolvedValue({ id: 'next', code: 'NEXT' }),
      },
    };
    const service = new BusinessService(prisma as any, {} as any, {} as any);
    await expect(
      service.currentInviteCode('business', 'previous'),
    ).resolves.toEqual({ code: { id: 'next', code: 'NEXT' } });
    expect(prisma.inviteCode.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          businessProfile: {
            userId: 'business',
            isActive: true,
            user: { role: 'BUSINESS', status: 'ACTIVE' },
          },
          status: 'UNUSED',
          id: { not: 'previous' },
          OR: [{ expiresAt: null }, { expiresAt: { gt: expect.any(Date) } }],
        }),
      }),
    );
  });
  it('keeps the sole remaining code and returns null for an empty pool', async () => {
    const prisma = {
      inviteCode: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce(null)
          .mockResolvedValueOnce({ id: 'only' })
          .mockResolvedValue(null),
      },
    };
    const service = new BusinessService(prisma as any, {} as any, {} as any);
    await expect(
      service.currentInviteCode('business', 'only'),
    ).resolves.toEqual({ code: { id: 'only' } });
    await expect(service.currentInviteCode('business')).resolves.toEqual({
      code: null,
    });
  });
  it.each([
    ['ADMIN', 'MANAGER'],
    ['MANAGER', 'BUSINESS'],
  ])('creates only the next level for %s', async (role, expectedRole) => {
    const tx = {
      user: { create: jest.fn().mockResolvedValue({ id: 'new' }) },
      auditLog: { create: jest.fn() },
    };
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({ role, status: 'ACTIVE' }),
      },
      $transaction: (fn: any) => fn(tx),
    };
    await new TeamService(prisma as any).create('actor', {
      employeeNo: 'EMP001',
      fullName: 'Employee',
      password: 'abcdef',
    });
    expect(tx.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          role: expectedRole,
          businessCreatorId: 'actor',
        }),
      }),
    );
  });
});
