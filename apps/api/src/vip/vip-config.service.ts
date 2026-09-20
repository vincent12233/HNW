import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { moneyDecimal } from '../common/money';
import {
  isVipTierCode,
  VIP_CONFIG_LOCK_KEY,
} from './vip.constants';
import { assertStrictlyIncreasingActiveThresholds } from './vip-recommendation';

export type UpdateVipTierInput = {
  displayName?: string;
  description?: string;
  minimumCumulativeDeposit?: string | null;
  displayOrder?: number;
  isActive?: boolean;
};

function parseOptionalThreshold(
  value: string | null | undefined,
  present: boolean,
): Prisma.Decimal | null | undefined {
  if (!present) return undefined;
  if (value == null || value === '') return null;
  try {
    const amount = new Prisma.Decimal(value);
    if (!amount.isFinite() || !amount.equals(amount.toDecimalPlaces(2))) {
      throw new BadRequestException(
        'VIP threshold cannot have more than two decimal places',
      );
    }
    if (amount.lt(0)) {
      throw new BadRequestException('VIP threshold cannot be negative');
    }
    return moneyDecimal(amount);
  } catch (error) {
    if (error instanceof BadRequestException) throw error;
    throw new BadRequestException('VIP threshold is invalid');
  }
}

@Injectable()
export class VipConfigService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async list() {
    const rows = await this.prisma.vipTierConfiguration.findMany({
      orderBy: { displayOrder: 'asc' },
      select: {
        tierCode: true,
        displayName: true,
        description: true,
        minimumCumulativeDeposit: true,
        displayOrder: true,
        isActive: true,
        updatedAt: true,
        updatedById: true,
        updatedBy: { select: { id: true, fullName: true, role: true } },
      },
    });
    return rows.map((row) => ({
      ...row,
      minimumCumulativeDeposit:
        row.minimumCumulativeDeposit?.toFixed(2) ?? null,
    }));
  }

  async update(actorId: string, tierCode: string, input: UpdateVipTierInput) {
    if (!isVipTierCode(tierCode)) {
      throw new BadRequestException('Unknown VIP tier');
    }
    const thresholdPresent = Object.prototype.hasOwnProperty.call(
      input,
      'minimumCumulativeDeposit',
    );
    const nextThreshold = parseOptionalThreshold(
      input.minimumCumulativeDeposit,
      thresholdPresent,
    );
    if (input.displayName !== undefined) {
      const name = input.displayName.trim();
      if (name.length < 1 || name.length > 40) {
        throw new BadRequestException('Display name must be 1-40 characters');
      }
    }
    if (input.description !== undefined && input.description.length > 240) {
      throw new BadRequestException('Description must be at most 240 characters');
    }
    if (
      input.displayOrder !== undefined &&
      (!Number.isInteger(input.displayOrder) ||
        input.displayOrder < 1 ||
        input.displayOrder > 40)
    ) {
      throw new BadRequestException('Display order must be an integer from 1 to 40');
    }

    return this.prisma.$transaction(
      async (tx) => {
        await tx.$executeRaw(
          Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${VIP_CONFIG_LOCK_KEY}))`,
        );
        const existing = await tx.vipTierConfiguration.findUnique({
          where: { tierCode },
        });
        if (!existing) throw new NotFoundException('VIP tier not found');
        const rows = await tx.vipTierConfiguration.findMany({
          orderBy: { displayOrder: 'asc' },
        });
        const nextRows = rows.map((row) => {
          if (row.tierCode !== tierCode) return row;
          return {
            ...row,
            displayName:
              input.displayName !== undefined
                ? input.displayName.trim()
                : row.displayName,
            description:
              input.description !== undefined
                ? input.description
                : row.description,
            minimumCumulativeDeposit:
              nextThreshold === undefined
                ? row.minimumCumulativeDeposit
                : nextThreshold,
            displayOrder:
              input.displayOrder !== undefined
                ? input.displayOrder
                : row.displayOrder,
            isActive:
              input.isActive !== undefined ? input.isActive : row.isActive,
          };
        });
        try {
          assertStrictlyIncreasingActiveThresholds(nextRows);
        } catch (error) {
          throw new BadRequestException(
            error instanceof Error
              ? error.message
              : 'Active VIP thresholds must increase strictly',
          );
        }
        const updated = await tx.vipTierConfiguration.update({
          where: { tierCode },
          data: {
            displayName:
              input.displayName !== undefined
                ? input.displayName.trim()
                : undefined,
            description: input.description,
            minimumCumulativeDeposit:
              nextThreshold === undefined ? undefined : nextThreshold,
            displayOrder: input.displayOrder,
            isActive: input.isActive,
            updatedById: actorId,
          },
        });
        await this.audit.createLog(
          {
            actorId,
            action: 'VIP_TIER_CONFIGURATION_UPDATED',
            resource: 'VipTierConfiguration',
            resourceId: tierCode,
            description: 'VIP membership threshold configuration changed',
            metadata: {
              previous: {
                displayName: existing.displayName,
                description: existing.description,
                minimumCumulativeDeposit:
                  existing.minimumCumulativeDeposit?.toFixed(2) ?? null,
                displayOrder: existing.displayOrder,
                isActive: existing.isActive,
              },
              next: {
                displayName: updated.displayName,
                description: updated.description,
                minimumCumulativeDeposit:
                  updated.minimumCumulativeDeposit?.toFixed(2) ?? null,
                displayOrder: updated.displayOrder,
                isActive: updated.isActive,
              },
            },
          },
          tx,
        );
        return {
          ...updated,
          minimumCumulativeDeposit:
            updated.minimumCumulativeDeposit?.toFixed(2) ?? null,
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );
  }
}
