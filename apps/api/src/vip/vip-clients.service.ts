import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { suggestVipTier, type VipConfigRow } from './vip-recommendation';
import { sumCumulativeConfirmedDeposit } from './vip-cumulative-deposit';
import { maskPhone } from './vip-phone';
import { applyManualVipTierChange } from './vip-tier-change';

export type VipClientScope = 'ADMIN' | 'MANAGER' | 'BUSINESS';

type ClientRow = {
  id: string;
  customerNo: string | null;
  fullName: string;
  phone: string | null;
  clientTier: string;
  assignedBusinessId: string | null;
  assignedBusiness: {
    id: string;
    fullName: string;
    businessCreatorId: string | null;
    businessProfile: { employeeNo: string | null } | null;
  } | null;
  account: { id: string } | null;
  vipTierChanges: { createdAt: Date }[];
};

@Injectable()
export class VipClientsService {
  constructor(private readonly prisma: PrismaService) {}

  private clientWhere(scope: VipClientScope, actorId: string): Prisma.UserWhereInput {
    if (scope === 'ADMIN') {
      return { role: 'CLIENT', deletedAt: null };
    }
    if (scope === 'MANAGER') {
      return {
        role: 'CLIENT',
        deletedAt: null,
        assignedBusiness: {
          is: {
            role: 'BUSINESS',
            deletedAt: null,
            businessCreatorId: actorId,
          },
        },
      };
    }
    return {
      role: 'CLIENT',
      deletedAt: null,
      assignedBusinessId: actorId,
    };
  }

  async list(scope: VipClientScope, actorId: string) {
    const [clients, configs] = await Promise.all([
      this.prisma.user.findMany({
        where: this.clientWhere(scope, actorId),
        select: {
          id: true,
          customerNo: true,
          fullName: true,
          phone: true,
          clientTier: true,
          assignedBusinessId: true,
          assignedBusiness: {
            select: {
              id: true,
              fullName: true,
              businessCreatorId: true,
              businessProfile: { select: { employeeNo: true } },
            },
          },
          account: { select: { id: true } },
          vipTierChanges: {
            orderBy: { createdAt: 'desc' },
            take: 1,
            select: { createdAt: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.vipTierConfiguration.findMany({
        orderBy: { displayOrder: 'asc' },
      }),
    ]);
    const rows = await Promise.all(
      clients.map((client) => this.serializeClient(client, configs)),
    );
    return {
      suggestionConfigured: configs.some(
        (row) => row.isActive && row.minimumCumulativeDeposit != null,
      ),
      clients: rows,
    };
  }

  async history(
    scope: VipClientScope,
    actorId: string,
    userId: string,
  ) {
    await this.assertVisibleClient(scope, actorId, userId);
    const rows = await this.prisma.vipTierHistory.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        previousTier: true,
        newTier: true,
        reason: true,
        source: true,
        suggestedTierAtChange: true,
        cumulativeDepositAtChange: true,
        createdAt: true,
        changedBy: {
          select: { id: true, fullName: true, role: true },
        },
      },
    });
    return rows.map((row) => ({
      ...row,
      cumulativeDepositAtChange: row.cumulativeDepositAtChange.toFixed(2),
    }));
  }

  async listRecentHistory(scope: VipClientScope, actorId: string) {
    return this.prisma.vipTierHistory.findMany({
      where: { user: this.clientWhere(scope, actorId) },
      orderBy: { createdAt: 'desc' },
      take: 200,
      select: {
        id: true,
        userId: true,
        previousTier: true,
        newTier: true,
        reason: true,
        source: true,
        suggestedTierAtChange: true,
        cumulativeDepositAtChange: true,
        createdAt: true,
        user: {
          select: {
            id: true,
            customerNo: true,
            fullName: true,
            phone: true,
          },
        },
        changedBy: {
          select: { id: true, fullName: true, role: true },
        },
      },
    }).then((rows) =>
      rows.map((row) => ({
        id: row.id,
        userId: row.userId,
        clientId: row.user.customerNo,
        displayName: row.user.fullName,
        maskedPhone: maskPhone(row.user.phone),
        previousTier: row.previousTier,
        newTier: row.newTier,
        reason: row.reason,
        source: row.source,
        suggestedTierAtChange: row.suggestedTierAtChange,
        cumulativeDepositAtChange: row.cumulativeDepositAtChange.toFixed(2),
        changedAt: row.createdAt,
        changedBy: row.changedBy,
      })),
    );
  }

  adjustOwnedClient(
    actorId: string,
    userId: string,
    tier: unknown,
    reason: unknown,
    source: 'MANUAL' | 'ADMIN',
    requireReason: boolean,
  ) {
    return this.prisma.$transaction(
      (tx) =>
        applyManualVipTierChange(tx, {
          actorId,
          userId,
          tier,
          reason,
          source,
          requireReason,
        }),
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );
  }

  private async assertVisibleClient(
    scope: VipClientScope,
    actorId: string,
    userId: string,
  ) {
    const client = await this.prisma.user.findFirst({
      where: { id: userId, ...this.clientWhere(scope, actorId) },
      select: { id: true },
    });
    if (!client) {
      throw scope === 'ADMIN'
        ? new NotFoundException('Client not found')
        : new ForbiddenException('Customer is outside the current VIP scope');
    }
  }

  private async serializeClient(client: ClientRow, configs: VipConfigRow[]) {
    const cumulative = await sumCumulativeConfirmedDeposit(
      this.prisma,
      client.account?.id,
    );
    const suggestion = suggestVipTier(configs, cumulative, client.clientTier);
    return {
      userId: client.id,
      clientId: client.customerNo,
      displayName: client.fullName,
      maskedPhone: maskPhone(client.phone),
      assignedBusiness: client.assignedBusiness
        ? {
            id: client.assignedBusiness.id,
            fullName: client.assignedBusiness.fullName,
            employeeNo: client.assignedBusiness.businessProfile?.employeeNo ?? null,
          }
        : null,
      currentTier: client.clientTier,
      cumulativeConfirmedDeposit: cumulative.toFixed(2),
      suggestedTier: suggestion.suggestedTier,
      suggestionStatus: suggestion.suggestionStatus,
      suggestionReason: suggestion.suggestionReason,
      configurationAsOf: suggestion.configurationAsOf,
      lastTierChangedAt: client.vipTierChanges[0]?.createdAt ?? null,
    };
  }
}
