import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTeamStaffDto } from './team.dto';
@Injectable()
export class TeamService {
  constructor(private readonly prisma: PrismaService) {}
  async actor(id: string) {
    const actor = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true, role: true, status: true },
    });
    if (
      !actor ||
      actor.status !== 'ACTIVE' ||
      !['ADMIN', 'MANAGER'].includes(actor.role)
    )
      throw new ForbiddenException();
    return actor;
  }
  async list(actorId: string) {
    const actor = await this.actor(actorId);
    const rows = await this.prisma.user.findMany({
      where:
        actor.role === 'ADMIN'
          ? { role: 'MANAGER', deletedAt: null }
          : { role: 'BUSINESS', businessCreatorId: actorId, deletedAt: null },
      select: {
        id: true,
        fullName: true,
        role: true,
        status: true,
        businessProfile: { select: { employeeNo: true, isActive: true } },
        _count: {
          select: { assignedCustomers: true, createdBusinessUsers: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    const vipCounts = await this.vipClientCounts(
      actor.role === 'ADMIN'
        ? (
            await this.prisma.user.findMany({
              where: {
                role: 'BUSINESS',
                deletedAt: null,
                businessCreatorId: { in: rows.map((row) => row.id) },
              },
              select: { id: true, businessCreatorId: true },
            })
          ).reduce(
            (map, business) => {
              if (!business.businessCreatorId) return map;
              const list = map.get(business.businessCreatorId) ?? [];
              list.push(business.id);
              map.set(business.businessCreatorId, list);
              return map;
            },
            new Map<string, string[]>(),
          )
        : new Map(rows.map((row) => [row.id, [row.id]])),
    );
    return rows.map((row) => ({
      ...row,
      vipClientCount: vipCounts.get(row.id) ?? 0,
    }));
  }

  private async vipClientCounts(ownedBusinessIds: Map<string, string[]>) {
    const result = new Map<string, number>();
    const businessIds = [...ownedBusinessIds.values()].flat();
    if (!businessIds.length) return result;
    const vip = await this.prisma.user.groupBy({
      by: ['assignedBusinessId'],
      where: {
        role: 'CLIENT',
        deletedAt: null,
        clientTier: { not: 'STANDARD' },
        assignedBusinessId: { in: businessIds },
      },
      _count: { _all: true },
    });
    const vipByBusiness = new Map(
      vip
        .filter((row) => row.assignedBusinessId)
        .map((row) => [row.assignedBusinessId as string, row._count._all]),
    );
    for (const [ownerId, ids] of ownedBusinessIds) {
      result.set(
        ownerId,
        ids.reduce((sum, id) => sum + (vipByBusiness.get(id) ?? 0), 0),
      );
    }
    return result;
  }
  async create(actorId: string, dto: CreateTeamStaffDto) {
    const actor = await this.actor(actorId);
    const role = actor.role === 'ADMIN' ? 'MANAGER' : 'BUSINESS';
    const passwordHash = await bcrypt.hash(dto.password, 12);
    try {
      return await this.prisma.$transaction(async (tx) => {
        const user = await tx.user.create({
          data: {
            email: dto.employeeNo.toLowerCase() + '@internal.hnw.local',
            fullName: dto.fullName,
            passwordHash,
            role,
            businessCreatorId: actorId,
            businessProfile: {
              create: { employeeNo: dto.employeeNo, isActive: true },
            },
          },
          select: {
            id: true,
            fullName: true,
            role: true,
            status: true,
            businessProfile: { select: { employeeNo: true } },
          },
        });
        await tx.auditLog.create({
          data: {
            actorId,
            action: 'TEAM_STAFF_CREATED',
            resource: 'USER',
            resourceId: user.id,
            metadata: { role },
          },
        });
        return user;
      });
    } catch (e) {
      if ((e as { code?: string }).code === 'P2002')
        throw new ConflictException('Employee number already exists');
      throw e;
    }
  }
  async business(actorId: string, businessId: string) {
    const actor = await this.actor(actorId);
    if (actor.role !== 'MANAGER') throw new ForbiddenException();
    const business = await this.prisma.user.findFirst({
      where: {
        id: businessId,
        role: 'BUSINESS',
        businessCreatorId: actorId,
        deletedAt: null,
      },
      select: { id: true },
    });
    if (!business)
      throw new NotFoundException('Business user not found in your team');
    return business.id;
  }
  async audit(actorId: string, targetId: string, action: string) {
    await this.prisma.auditLog.create({
      data: { actorId, action, resource: 'TEAM', resourceId: targetId },
    });
  }

  async remove(actorId: string, targetId: string) {
    const actor = await this.actor(actorId);
    return this.prisma.$transaction(
      async (tx) => {
        const target = await tx.user.findFirst({
          where: {
            id: targetId,
            deletedAt: null,
            ...(actor.role === 'ADMIN'
              ? { role: { in: ['MANAGER' as const, 'BUSINESS' as const] } }
              : { role: 'BUSINESS' as const, businessCreatorId: actorId }),
          },
          select: { id: true, role: true },
        });
        if (!target || targetId === actorId)
          throw new NotFoundException('未找到可删除的团队账号');
        const businessCount = await tx.user.count({
          where: {
            deletedAt: null,
            role: 'BUSINESS',
            businessCreatorId: targetId,
          },
        });
        const clientCount = await tx.user.count({
          where: {
            deletedAt: null,
            role: 'CLIENT',
            assignedBusinessId: targetId,
          },
        });
        if (target.role === 'MANAGER' && businessCount) {
          throw new ConflictException(
            `该管理员名下仍有 ${businessCount} 名业务员，请先转移归属后再删除`,
          );
        }
        if (target.role === 'BUSINESS' && clientCount) {
          throw new ConflictException(
            `该业务员名下仍有 ${clientCount} 名客户，请先处理客户归属后再删除`,
          );
        }
        await tx.user.update({
          where: { id: targetId },
          data: {
            deletedAt: new Date(),
            status: 'DISABLED',
            authVersion: { increment: 1 },
          },
        });
        await tx.businessProfile.updateMany({
          where: { userId: targetId },
          data: { isActive: false },
        });
        await tx.inviteCode.updateMany({
          where: { businessProfile: { userId: targetId }, status: 'UNUSED' },
          data: { status: 'DISABLED', disabledAt: new Date() },
        });
        await tx.auditLog.create({
          data: {
            actorId,
            action: 'TEAM_STAFF_DELETED',
            resource: 'USER',
            resourceId: targetId,
            metadata: { role: target.role },
          },
        });
        return { deleted: true, id: targetId };
      },
      { isolationLevel: 'Serializable' },
    );
  }
}
