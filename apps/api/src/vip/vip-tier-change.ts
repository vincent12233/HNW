import {
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { isVipTierCode } from './vip.constants';
import { suggestVipTier } from './vip-recommendation';
import { sumCumulativeConfirmedDeposit } from './vip-cumulative-deposit';

export type VipTierChangeSource = 'MANUAL' | 'ADMIN';

type TierChangeClient = Prisma.TransactionClient;

export async function applyManualVipTierChange(
  tx: TierChangeClient,
  input: {
    actorId: string;
    userId: string;
    tier: unknown;
    reason?: unknown;
    source: VipTierChangeSource;
    requireReason: boolean;
  },
) {
  if (!isVipTierCode(input.tier)) {
    throw new BadRequestException(
      input.source === 'ADMIN' ? 'Invalid client tier' : 'Invalid membership tier',
    );
  }
  const note = typeof input.reason === 'string' ? input.reason.trim() : '';
  if (input.requireReason && note.length < 4) {
    throw new BadRequestException('Adjustment reason is required');
  }
  const resolvedReason =
    note ||
    (input.source === 'ADMIN'
      ? 'Membership tier updated by administrator'
      : 'Membership tier updated by business operator');
  if (resolvedReason.length > 240) {
    throw new BadRequestException('Adjustment reason is too long');
  }

  const where: Prisma.UserWhereInput =
    input.source === 'MANUAL'
      ? {
          id: input.userId,
          role: 'CLIENT',
          assignedBusinessId: input.actorId,
          deletedAt: null,
        }
      : { id: input.userId, role: 'CLIENT', deletedAt: null };

  await tx.$executeRaw(
    Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${`hnw.vip_client:${input.userId}`}))`,
  );

  const user = await tx.user.findFirst({
    where,
    select: {
      id: true,
      role: true,
      clientTier: true,
      account: { select: { id: true } },
    },
  });
  if (!user || user.role !== 'CLIENT') {
    throw new NotFoundException(
      input.source === 'MANUAL'
        ? 'Customer not assigned to this business user'
        : 'Client not found',
    );
  }

  const recent = await tx.vipTierHistory.findFirst({
    where: {
      userId: user.id,
      changedById: input.actorId,
      newTier: input.tier,
      reason: resolvedReason,
      createdAt: { gte: new Date(Date.now() - 15_000) },
    },
    orderBy: { createdAt: 'desc' },
  });
  if (recent && user.clientTier === input.tier) {
    return { id: user.id, clientTier: user.clientTier };
  }

  const configs = await tx.vipTierConfiguration.findMany({
    orderBy: { displayOrder: 'asc' },
  });
  const cumulative = await sumCumulativeConfirmedDeposit(tx, user.account?.id);
  const suggestion = suggestVipTier(configs, cumulative, user.clientTier);

  if (user.clientTier !== input.tier) {
    const updated = await tx.user.updateMany({
      where,
      data: { clientTier: input.tier },
    });
    if (updated.count !== 1) {
      throw new NotFoundException(
        input.source === 'MANUAL'
          ? 'Customer assignment changed'
          : 'Client not found',
      );
    }
  }

  await tx.vipTierHistory.create({
    data: {
      userId: user.id,
      previousTier: user.clientTier,
      newTier: input.tier,
      reason: resolvedReason,
      source: input.source,
      suggestedTierAtChange: suggestion.suggestedTier,
      cumulativeDepositAtChange: cumulative,
      changedById: input.actorId,
    },
  });
  await tx.auditLog.create({
    data: {
      actorId: input.actorId,
      action:
        input.source === 'ADMIN'
          ? 'CLIENT_TIER_UPDATED'
          : 'BUSINESS_CLIENT_TIER_UPDATED',
      resource: 'User',
      resourceId: user.id,
      description: 'Manual VIP membership change',
      metadata: {
        previous: user.clientTier,
        tier: input.tier,
        reason: resolvedReason,
        source: input.source,
        suggestedTier: suggestion.suggestedTier,
        cumulativeConfirmedDeposit: cumulative.toFixed(2),
      },
    },
  });
  return { id: user.id, clientTier: input.tier };
}
