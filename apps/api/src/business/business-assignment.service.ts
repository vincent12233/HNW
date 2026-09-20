import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';

const STAFF_SELECT = {
  id: true,
  fullName: true,
  role: true,
  status: true,
  deletedAt: true,
  businessCreatorId: true,
  businessProfile: { select: { employeeNo: true, isActive: true } },
} satisfies Prisma.UserSelect;

type StaffRow = Prisma.UserGetPayload<{ select: typeof STAFF_SELECT }>;

export type AssignBusinessInput = {
  businessUserId: string;
  newManagerId: string;
  reason: string;
  expectedCurrentManagerId: string | null;
  idempotencyKey: string;
};

@Injectable()
export class BusinessAssignmentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async listAssignments(
    actorId: string,
    query: { search?: string; managerId?: string } = {},
  ) {
    await this.requireAdmin(actorId);
    const search = query.search?.trim();
    const managerFilter = query.managerId?.trim();
    const [managers, businesses] = await Promise.all([
      this.prisma.user.findMany({
        where: { role: UserRole.MANAGER, deletedAt: null },
        select: STAFF_SELECT,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.user.findMany({
        where: {
          role: UserRole.BUSINESS,
          deletedAt: null,
          ...(search
            ? {
                OR: [
                  { fullName: { contains: search, mode: 'insensitive' } },
                  {
                    businessProfile: {
                      is: {
                        employeeNo: { contains: search, mode: 'insensitive' },
                      },
                    },
                  },
                ],
              }
            : {}),
        },
        select: STAFF_SELECT,
        orderBy: { createdAt: 'desc' },
      }),
    ]);
    const counts = await this.clientCounts(
      businesses.map((row) => row.id),
    );
    const managerMap = new Map(managers.map((row) => [row.id, row]));
    const grouped = new Map<
      string,
      { manager: StaffRow; businesses: ReturnType<BusinessAssignmentService['toBusinessRow']>[] }
    >();
    for (const manager of managers) {
      grouped.set(manager.id, { manager, businesses: [] });
    }
    const unassigned: ReturnType<BusinessAssignmentService['toBusinessRow']>[] =
      [];
    for (const business of businesses) {
      const managerId = this.effectiveManagerId(business, managerMap);
      const row = this.toBusinessRow(
        business,
        counts.get(business.id),
        managerId,
      );
      if (managerId && grouped.has(managerId)) {
        grouped.get(managerId)!.businesses.push(row);
      } else {
        unassigned.push(row);
      }
    }
    let managerRows = [...grouped.values()].map(({ manager, businesses: team }) => ({
      ...this.toStaffRow(manager),
      businessCount: team.length,
      clientCount: team.reduce((sum, item) => sum + item.clientCount, 0),
      vipClientCount: team.reduce((sum, item) => sum + item.vipClientCount, 0),
      businesses: team,
    }));
    let unassignedRows = unassigned;
    if (managerFilter === 'unassigned') {
      managerRows = [];
    } else if (managerFilter) {
      managerRows = managerRows.filter((row) => row.id === managerFilter);
      unassignedRows = [];
    }
    if (search) {
      managerRows = managerRows.filter(
        (row) =>
          row.businesses.length > 0 ||
          row.fullName.toLowerCase().includes(search.toLowerCase()) ||
          (row.employeeNo ?? '').toLowerCase().includes(search.toLowerCase()),
      );
    }
    const allBusinessRows = [
      ...[...grouped.values()].flatMap((item) => item.businesses),
      ...unassigned,
    ];
    return {
      managers: managerRows,
      unassigned: unassignedRows,
      managerOptions: managers.map((row) => this.toStaffRow(row)),
      totals: {
        managerCount: managers.length,
        businessCount: businesses.length,
        unassignedCount: unassigned.length,
        clientCount: allBusinessRows.reduce(
          (sum, row) => sum + row.clientCount,
          0,
        ),
      },
    };
  }

  async preview(actorId: string, input: { businessUserId: string; newManagerId: string }) {
    await this.requireAdmin(actorId);
    const [business, newManager] = await Promise.all([
      this.prisma.user.findFirst({
        where: {
          id: input.businessUserId,
          role: UserRole.BUSINESS,
          deletedAt: null,
        },
        select: STAFF_SELECT,
      }),
      this.prisma.user.findFirst({
        where: {
          id: input.newManagerId,
          role: UserRole.MANAGER,
          deletedAt: null,
        },
        select: STAFF_SELECT,
      }),
    ]);
    if (!business) throw new NotFoundException('未找到可分配的业务员');
    if (!newManager) throw new NotFoundException('未找到目标管理员');
    const currentManager = await this.loadEffectiveManager(business.businessCreatorId);
    const counts = await this.clientCounts([business.id]);
    const stats = counts.get(business.id) ?? { clientCount: 0, vipClientCount: 0 };
    const warnings = [
      '客户仍归属于该业务员，不会修改 assignedBusinessId',
      '旧管理员将失去该业务员及名下客户的团队可见性',
      '新管理员通过该业务员获得团队范围内的客户可见性',
    ];
    if (newManager.status !== UserStatus.ACTIVE) {
      warnings.push('目标管理员当前不是启用状态');
    }
    if (this.effectiveManagerId(business, currentManager ? new Map([[currentManager.id, currentManager]]) : new Map()) === newManager.id) {
      warnings.push('业务员已归属该管理员');
    }
    return {
      business: this.toStaffRow(business),
      currentManager: currentManager ? this.toStaffRow(currentManager) : null,
      newManager: this.toStaffRow(newManager),
      clientCount: stats.clientCount,
      vipClientCount: stats.vipClientCount,
      warnings,
    };
  }

  async historyForAdmin(actorId: string, businessUserId: string) {
    await this.requireAdmin(actorId);
    const business = await this.prisma.user.findFirst({
      where: { id: businessUserId, role: UserRole.BUSINESS },
      select: { id: true },
    });
    if (!business) throw new NotFoundException('未找到业务员');
    return this.listHistory({ businessUserId });
  }

  async historyForManager(actorId: string) {
    await this.requireManager(actorId);
    return this.listHistory({
      OR: [{ previousManagerId: actorId }, { newManagerId: actorId }],
    });
  }

  async listManagerTeam(actorId: string) {
    await this.requireManager(actorId);
    const businesses = await this.prisma.user.findMany({
      where: {
        role: UserRole.BUSINESS,
        businessCreatorId: actorId,
        deletedAt: null,
      },
      select: STAFF_SELECT,
      orderBy: { createdAt: 'desc' },
    });
    const counts = await this.clientCounts(businesses.map((row) => row.id));
    return businesses.map((row) =>
      this.toBusinessRow(row, counts.get(row.id), actorId),
    );
  }

  async listManagerCustomers(actorId: string) {
    await this.requireManager(actorId);
    return this.prisma.user.findMany({
      where: {
        role: UserRole.CLIENT,
        deletedAt: null,
        assignedBusiness: {
          is: {
            role: UserRole.BUSINESS,
            deletedAt: null,
            businessCreatorId: actorId,
          },
        },
      },
      select: {
        id: true,
        customerNo: true,
        fullName: true,
        status: true,
        clientTier: true,
        assignedBusinessId: true,
        assignedBusiness: {
          select: {
            id: true,
            fullName: true,
            businessProfile: { select: { employeeNo: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async assignOrTransferBusinessToManager(
    actorId: string,
    input: AssignBusinessInput,
  ) {
    const reason = input.reason.trim();
    const idempotencyKey = input.idempotencyKey.trim();
    if (!reason) throw new BadRequestException('请填写归属变更原因');
    if (!idempotencyKey) throw new ConflictException('幂等键不能为空');

    return this.prisma.$transaction(
      async (tx) => {
        const replay = await this.replayIfPresent(tx, idempotencyKey, input);
        if (replay) return replay;

        const actor = await tx.user.findUnique({
          where: { id: actorId },
          select: { id: true, role: true, status: true, deletedAt: true },
        });
        if (
          !actor ||
          actor.deletedAt ||
          actor.status !== UserStatus.ACTIVE ||
          actor.role !== UserRole.ADMIN
        ) {
          throw new ForbiddenException('只有超级管理员可以分配或转移业务员');
        }

        await tx.$queryRaw(
          Prisma.sql`SELECT id FROM "users" WHERE id = ${input.businessUserId} FOR UPDATE`,
        );
        const business = await tx.user.findFirst({
          where: { id: input.businessUserId, deletedAt: null },
          select: STAFF_SELECT,
        });
        if (!business) throw new NotFoundException('未找到可分配的业务员');
        if (business.role !== UserRole.BUSINESS) {
          throw new BadRequestException('只能分配业务员账号');
        }

        const newManager = await tx.user.findFirst({
          where: { id: input.newManagerId, deletedAt: null },
          select: STAFF_SELECT,
        });
        if (!newManager) throw new NotFoundException('未找到目标管理员');
        if (newManager.role !== UserRole.MANAGER) {
          throw new BadRequestException('目标必须是管理员账号');
        }
        if (newManager.status !== UserStatus.ACTIVE) {
          throw new ConflictException('目标管理员未启用，无法接收业务员');
        }

        const currentManager = await this.loadEffectiveManager(
          business.businessCreatorId,
          tx,
        );
        const currentManagerId = currentManager?.id ?? null;
        if (currentManagerId !== input.expectedCurrentManagerId) {
          throw new ConflictException('业务员当前归属已变化，请刷新后重试');
        }
        if (currentManagerId === newManager.id) {
          throw new ConflictException('业务员已归属该管理员');
        }

        const clientCount = await tx.user.count({
          where: {
            role: UserRole.CLIENT,
            assignedBusinessId: business.id,
            deletedAt: null,
          },
        });

        await tx.user.update({
          where: { id: business.id },
          data: { businessCreatorId: newManager.id },
        });

        let history;
        try {
          history = await tx.businessManagerAssignmentHistory.create({
            data: {
              businessUserId: business.id,
              previousManagerId: currentManagerId,
              newManagerId: newManager.id,
              reason,
              changedById: actor.id,
              idempotencyKey,
              businessEmployeeNo: business.businessProfile?.employeeNo ?? null,
              previousManagerEmployeeNo:
                currentManager?.businessProfile?.employeeNo ?? null,
              newManagerEmployeeNo: newManager.businessProfile?.employeeNo ?? null,
              clientCountAtChange: clientCount,
            },
          });
        } catch (error: unknown) {
          if (
            error instanceof Prisma.PrismaClientKnownRequestError &&
            error.code === 'P2002'
          ) {
            const raced = await this.replayIfPresent(tx, idempotencyKey, input);
            if (raced) return raced;
          }
          throw error;
        }

        await this.audit.createLog(
          {
            actorId: actor.id,
            action: currentManagerId
              ? 'BUSINESS_MANAGER_TRANSFERRED'
              : 'BUSINESS_MANAGER_ASSIGNED',
            resource: 'BUSINESS_ASSIGNMENT',
            resourceId: business.id,
            description: currentManagerId
              ? `Transferred business user from manager ${currentManagerId} to ${newManager.id}`
              : `Assigned business user to manager ${newManager.id}`,
            metadata: {
              businessUserId: business.id,
              previousManagerId: currentManagerId,
              newManagerId: newManager.id,
              historyId: history.id,
              clientCountAtChange: clientCount,
              assignedBusinessIdUnchanged: true,
            },
          },
          tx,
        );

        return this.toTransferResult({
          businessUserId: business.id,
          previousManagerId: currentManagerId,
          newManagerId: newManager.id,
          historyId: history.id,
          replayed: false,
          clientCount,
        });
      },
      { isolationLevel: 'Serializable' },
    );
  }

  private async replayIfPresent(
    tx: Prisma.TransactionClient,
    idempotencyKey: string,
    input: AssignBusinessInput,
  ) {
    const existing = await tx.businessManagerAssignmentHistory.findUnique({
      where: { idempotencyKey },
    });
    if (!existing) return null;
    if (
      existing.businessUserId !== input.businessUserId ||
      existing.newManagerId !== input.newManagerId
    ) {
      throw new ConflictException('幂等键已用于其他归属变更');
    }
    const current = await tx.user.findUnique({
      where: { id: existing.businessUserId },
      select: { businessCreatorId: true },
    });
    return this.toTransferResult({
      businessUserId: existing.businessUserId,
      previousManagerId: existing.previousManagerId,
      newManagerId: existing.newManagerId,
      historyId: existing.id,
      replayed: true,
      clientCount: existing.clientCountAtChange,
      currentManagerId: current?.businessCreatorId ?? existing.newManagerId,
    });
  }

  private toTransferResult(input: {
    businessUserId: string;
    previousManagerId: string | null;
    newManagerId: string | null;
    historyId: string;
    replayed: boolean;
    clientCount: number;
    currentManagerId?: string | null;
  }) {
    return {
      businessUserId: input.businessUserId,
      previousManagerId: input.previousManagerId,
      newManagerId: input.newManagerId,
      currentManagerId: input.currentManagerId ?? input.newManagerId,
      historyId: input.historyId,
      replayed: input.replayed,
      clientCount: input.clientCount,
      assignedBusinessIdUnchanged: true as const,
      vipUnchanged: true as const,
    };
  }

  private async listHistory(where: Prisma.BusinessManagerAssignmentHistoryWhereInput) {
    const rows = await this.prisma.businessManagerAssignmentHistory.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 200,
      select: {
        id: true,
        businessUserId: true,
        previousManagerId: true,
        newManagerId: true,
        reason: true,
        changedById: true,
        businessEmployeeNo: true,
        previousManagerEmployeeNo: true,
        newManagerEmployeeNo: true,
        clientCountAtChange: true,
        createdAt: true,
        businessUser: { select: { fullName: true } },
        previousManager: { select: { fullName: true } },
        newManager: { select: { fullName: true } },
        changedBy: { select: { fullName: true } },
      },
    });
    return rows.map((row) => ({
      id: row.id,
      businessUserId: row.businessUserId,
      businessName: row.businessUser.fullName,
      businessEmployeeNo: row.businessEmployeeNo,
      previousManagerId: row.previousManagerId,
      previousManagerName: row.previousManager?.fullName ?? null,
      previousManagerEmployeeNo: row.previousManagerEmployeeNo,
      newManagerId: row.newManagerId,
      newManagerName: row.newManager?.fullName ?? null,
      newManagerEmployeeNo: row.newManagerEmployeeNo,
      reason: row.reason,
      changedById: row.changedById,
      changedByName: row.changedBy.fullName,
      clientCountAtChange: row.clientCountAtChange,
      createdAt: row.createdAt,
    }));
  }

  private async clientCounts(businessIds: string[]) {
    const empty = new Map<string, { clientCount: number; vipClientCount: number }>();
    if (!businessIds.length) return empty;
    const [all, vip] = await Promise.all([
      this.prisma.user.groupBy({
        by: ['assignedBusinessId'],
        where: {
          role: UserRole.CLIENT,
          deletedAt: null,
          assignedBusinessId: { in: businessIds },
        },
        _count: { _all: true },
      }),
      this.prisma.user.groupBy({
        by: ['assignedBusinessId'],
        where: {
          role: UserRole.CLIENT,
          deletedAt: null,
          clientTier: { not: 'STANDARD' },
          assignedBusinessId: { in: businessIds },
        },
        _count: { _all: true },
      }),
    ]);
    const result = new Map<string, { clientCount: number; vipClientCount: number }>();
    for (const id of businessIds) {
      result.set(id, { clientCount: 0, vipClientCount: 0 });
    }
    for (const row of all) {
      if (!row.assignedBusinessId) continue;
      result.set(row.assignedBusinessId, {
        clientCount: row._count._all,
        vipClientCount: 0,
      });
    }
    for (const row of vip) {
      if (!row.assignedBusinessId) continue;
      const current = result.get(row.assignedBusinessId) ?? {
        clientCount: 0,
        vipClientCount: 0,
      };
      current.vipClientCount = row._count._all;
      result.set(row.assignedBusinessId, current);
    }
    return result;
  }

  private effectiveManagerId(
    business: Pick<StaffRow, 'businessCreatorId'>,
    managers: Map<string, StaffRow>,
  ) {
    if (!business.businessCreatorId) return null;
    const manager = managers.get(business.businessCreatorId);
    return manager && manager.role === UserRole.MANAGER ? manager.id : null;
  }

  private async loadEffectiveManager(
    managerId: string | null,
    tx: Prisma.TransactionClient | PrismaService = this.prisma,
  ) {
    if (!managerId) return null;
    const manager = await tx.user.findFirst({
      where: { id: managerId, role: UserRole.MANAGER, deletedAt: null },
      select: STAFF_SELECT,
    });
    return manager;
  }

  private async requireAdmin(actorId: string) {
    const actor = await this.prisma.user.findUnique({
      where: { id: actorId },
      select: { id: true, role: true, status: true, deletedAt: true },
    });
    if (
      !actor ||
      actor.deletedAt ||
      actor.status !== UserStatus.ACTIVE ||
      actor.role !== UserRole.ADMIN
    ) {
      throw new ForbiddenException('只有超级管理员可以管理业务员归属');
    }
    return actor;
  }

  private async requireManager(actorId: string) {
    const actor = await this.prisma.user.findUnique({
      where: { id: actorId },
      select: { id: true, role: true, status: true, deletedAt: true },
    });
    if (
      !actor ||
      actor.deletedAt ||
      actor.status !== UserStatus.ACTIVE ||
      actor.role !== UserRole.MANAGER
    ) {
      throw new ForbiddenException('仅管理员可查看自己的团队归属');
    }
    return actor;
  }

  private toStaffRow(row: StaffRow) {
    return {
      id: row.id,
      fullName: row.fullName,
      role: row.role,
      status: row.status,
      employeeNo: row.businessProfile?.employeeNo ?? null,
      isActive: row.businessProfile?.isActive ?? null,
    };
  }

  private toBusinessRow(
    row: StaffRow,
    counts: { clientCount: number; vipClientCount: number } | undefined,
    currentManagerId: string | null,
  ) {
    return {
      ...this.toStaffRow(row),
      currentManagerId,
      clientCount: counts?.clientCount ?? 0,
      vipClientCount: counts?.vipClientCount ?? 0,
    };
  }
}
