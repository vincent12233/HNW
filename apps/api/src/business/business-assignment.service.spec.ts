import { ConflictException, ForbiddenException } from '@nestjs/common';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { BusinessAssignmentService } from './business-assignment.service';

describe('Business manager assignment service', () => {
  const business = {
    id: 'biz-1',
    fullName: 'Agent One',
    role: UserRole.BUSINESS,
    status: UserStatus.ACTIVE,
    deletedAt: null,
    businessCreatorId: 'mgr-a',
    businessProfile: { employeeNo: 'B001', isActive: true },
  };
  const managerA = {
    id: 'mgr-a',
    fullName: 'Manager A',
    role: UserRole.MANAGER,
    status: UserStatus.ACTIVE,
    deletedAt: null,
    businessCreatorId: 'admin-1',
    businessProfile: { employeeNo: 'M001', isActive: true },
  };
  const managerB = {
    ...managerA,
    id: 'mgr-b',
    fullName: 'Manager B',
    businessProfile: { employeeNo: 'M002', isActive: true },
  };
  const admin = {
    id: 'admin-1',
    role: UserRole.ADMIN,
    status: UserStatus.ACTIVE,
    deletedAt: null,
  };

  function setup() {
    const tx = {
      $queryRaw: jest.fn().mockResolvedValue([{ id: 'biz-1' }]),
      user: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        update: jest.fn().mockResolvedValue(business),
        count: jest.fn().mockResolvedValue(2),
      },
      businessManagerAssignmentHistory: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({
          id: 'hist-1',
          businessUserId: 'biz-1',
          previousManagerId: 'mgr-a',
          newManagerId: 'mgr-b',
          clientCountAtChange: 2,
        }),
      },
    };
    tx.user.findUnique.mockImplementation(({ where }: { where: { id: string } }) => {
      if (where.id === 'admin-1') return Promise.resolve(admin);
      return Promise.resolve(null);
    });
    tx.user.findFirst.mockImplementation(
      ({ where }: { where: { id?: string; role?: string } }) => {
        if (where.id === 'biz-1') return Promise.resolve(business);
        if (where.id === 'mgr-a') return Promise.resolve(managerA);
        if (where.id === 'mgr-b') return Promise.resolve(managerB);
        return Promise.resolve(null);
      },
    );
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(admin),
        findMany: jest.fn(),
        groupBy: jest.fn().mockResolvedValue([]),
      },
      $transaction: (fn: (client: typeof tx) => unknown) => fn(tx),
    };
    const audit = { createLog: jest.fn().mockResolvedValue({ id: 'audit-1' }) };
    const service = new BusinessAssignmentService(prisma as never, audit as never);
    return { service, tx, prisma, audit };
  }

  const payload = {
    businessUserId: 'biz-1',
    newManagerId: 'mgr-b',
    reason: 'Rebalance team coverage',
    expectedCurrentManagerId: 'mgr-a',
    idempotencyKey: 'assign-key-0001',
  };

  it('transfers businessCreatorId, writes history and audit, and leaves clients untouched', async () => {
    const { service, tx, audit } = setup();
    const result = await service.assignOrTransferBusinessToManager(
      'admin-1',
      payload,
    );
    expect(tx.user.update).toHaveBeenCalledWith({
      where: { id: 'biz-1' },
      data: { businessCreatorId: 'mgr-b' },
    });
    expect(tx.user.update.mock.calls[0][0].data.assignedBusinessId).toBeUndefined();
    expect(tx.user.update.mock.calls[0][0].data.clientTier).toBeUndefined();
    expect(tx.businessManagerAssignmentHistory.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          businessUserId: 'biz-1',
          previousManagerId: 'mgr-a',
          newManagerId: 'mgr-b',
          reason: payload.reason,
          idempotencyKey: payload.idempotencyKey,
          clientCountAtChange: 2,
        }),
      }),
    );
    expect(audit.createLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'BUSINESS_MANAGER_TRANSFERRED',
        metadata: expect.objectContaining({
          assignedBusinessIdUnchanged: true,
        }),
      }),
      tx,
    );
    expect(result).toMatchObject({
      replayed: false,
      newManagerId: 'mgr-b',
      assignedBusinessIdUnchanged: true,
      vipUnchanged: true,
    });
  });

  it('assigns an unowned business user without rewriting customers', async () => {
    const { service, tx } = setup();
    tx.user.findFirst.mockImplementation(
      ({ where }: { where: { id?: string; role?: string } }) => {
        if (where.id === 'biz-1') {
          return Promise.resolve({ ...business, businessCreatorId: null });
        }
        if (where.id === 'mgr-b') return Promise.resolve(managerB);
        return Promise.resolve(null);
      },
    );
    await service.assignOrTransferBusinessToManager('admin-1', {
      ...payload,
      expectedCurrentManagerId: null,
    });
    expect(tx.businessManagerAssignmentHistory.create.mock.calls[0][0].data).toMatchObject({
      previousManagerId: null,
      newManagerId: 'mgr-b',
    });
  });

  it('replays the same idempotency key without a second history row', async () => {
    const { service, tx, audit } = setup();
    tx.businessManagerAssignmentHistory.findUnique.mockResolvedValue({
      id: 'hist-1',
      businessUserId: 'biz-1',
      previousManagerId: 'mgr-a',
      newManagerId: 'mgr-b',
      clientCountAtChange: 2,
    });
    tx.user.findUnique.mockResolvedValue({ businessCreatorId: 'mgr-b' });
    const result = await service.assignOrTransferBusinessToManager(
      'admin-1',
      payload,
    );
    expect(result.replayed).toBe(true);
    expect(tx.user.update).not.toHaveBeenCalled();
    expect(tx.businessManagerAssignmentHistory.create).not.toHaveBeenCalled();
    expect(audit.createLog).not.toHaveBeenCalled();
  });

  it('rejects a reused idempotency key for a different transfer', async () => {
    const { service, tx } = setup();
    tx.businessManagerAssignmentHistory.findUnique.mockResolvedValue({
      id: 'hist-1',
      businessUserId: 'other-biz',
      newManagerId: 'mgr-b',
    });
    await expect(
      service.assignOrTransferBusinessToManager('admin-1', payload),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(tx.user.update).not.toHaveBeenCalled();
  });

  it('rejects stale expectedCurrentManagerId as a concurrent conflict', async () => {
    const { service, tx } = setup();
    await expect(
      service.assignOrTransferBusinessToManager('admin-1', {
        ...payload,
        expectedCurrentManagerId: 'mgr-stale',
      }),
    ).rejects.toThrow('当前归属已变化');
    expect(tx.user.update).not.toHaveBeenCalled();
  });

  it('rejects transferring onto the current manager', async () => {
    const { service, tx } = setup();
    await expect(
      service.assignOrTransferBusinessToManager('admin-1', {
        ...payload,
        newManagerId: 'mgr-a',
        expectedCurrentManagerId: 'mgr-a',
      }),
    ).rejects.toThrow('已归属该管理员');
    expect(tx.user.update).not.toHaveBeenCalled();
  });

  it.each([
    UserRole.MANAGER,
    UserRole.BUSINESS,
    UserRole.FINANCE,
    UserRole.SUPPORT,
    UserRole.CLIENT,
  ])('rejects %s as the transfer actor', async (role) => {
    const { service, tx } = setup();
    tx.user.findUnique.mockResolvedValue({
      id: 'actor',
      role,
      status: UserStatus.ACTIVE,
      deletedAt: null,
    });
    await expect(
      service.assignOrTransferBusinessToManager('actor', payload),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(tx.user.update).not.toHaveBeenCalled();
  });

  it('rejects non-business and non-manager roles', async () => {
    const { service, tx } = setup();
    tx.user.findFirst.mockImplementation(
      ({ where }: { where: { id?: string } }) => {
        if (where.id === 'biz-1') {
          return Promise.resolve({ ...business, role: UserRole.FINANCE });
        }
        return Promise.resolve(null);
      },
    );
    await expect(
      service.assignOrTransferBusinessToManager('admin-1', payload),
    ).rejects.toThrow('只能分配业务员');
  });

  it('preview is read-only', async () => {
    const { service, prisma } = setup();
    prisma.user.findFirst = jest.fn(
      ({ where }: { where: { id?: string } }) => {
        if (where.id === 'biz-1') return Promise.resolve(business);
        if (where.id === 'mgr-a') return Promise.resolve(managerA);
        if (where.id === 'mgr-b') return Promise.resolve(managerB);
        return Promise.resolve(null);
      },
    );
    prisma.user.findUnique.mockResolvedValue(admin);
    prisma.user.groupBy.mockResolvedValue([]);
    prisma.$transaction = jest.fn();
    const result = await service.preview('admin-1', {
      businessUserId: 'biz-1',
      newManagerId: 'mgr-b',
    });
    expect(result.clientCount).toBe(0);
    expect(result.currentManager?.id).toBe('mgr-a');
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('keeps manager team lists scoped to businessCreatorId', async () => {
    const { service, prisma } = setup();
    prisma.user.findUnique.mockResolvedValue({
      id: 'mgr-a',
      role: UserRole.MANAGER,
      status: UserStatus.ACTIVE,
      deletedAt: null,
    });
    prisma.user.findMany.mockResolvedValue([]);
    await service.listManagerTeam('mgr-a');
    expect(prisma.user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          role: UserRole.BUSINESS,
          businessCreatorId: 'mgr-a',
        }),
      }),
    );
    await service.listManagerCustomers('mgr-a');
    expect(prisma.user.findMany.mock.calls[1][0].where.assignedBusiness).toEqual({
      is: {
        role: UserRole.BUSINESS,
        deletedAt: null,
        businessCreatorId: 'mgr-a',
      },
    });
  });

  it('hides other teams from manager assignment history', async () => {
    const { service, prisma } = setup();
    prisma.user.findUnique.mockResolvedValue({
      id: 'mgr-a',
      role: UserRole.MANAGER,
      status: UserStatus.ACTIVE,
      deletedAt: null,
    });
    prisma.businessManagerAssignmentHistory = {
      findMany: jest.fn().mockResolvedValue([]),
    };
    await service.historyForManager('mgr-a');
    expect(prisma.businessManagerAssignmentHistory.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          OR: [{ previousManagerId: 'mgr-a' }, { newManagerId: 'mgr-a' }],
        },
      }),
    );
  });
});
