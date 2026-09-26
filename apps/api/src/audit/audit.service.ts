import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { currentRequestId } from '../common/request-context';
import { PrismaService } from '../prisma/prisma.service';

interface CreateAuditLogInput {
  actorId?: string;
  action: string;
  resource: string;
  resourceId?: string;
  description?: string;
  ipAddress?: string;
  userAgent?: string;
  metadata?: Prisma.InputJsonValue;
  idempotencyKey?: string | null;
  result?: string;
  statusVersion?: number | string;
}

@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  createLog(input: CreateAuditLogInput, tx?: Prisma.TransactionClient) {
    return (tx ?? this.prisma).auditLog.create({
      data: {
        actorId: input.actorId,
        action: input.action,
        resource: input.resource,
        resourceId: input.resourceId,
        description: input.description,
        ipAddress: input.ipAddress,
        userAgent: input.userAgent,
        metadata: {
          ...(input.metadata &&
          typeof input.metadata === 'object' &&
          !Array.isArray(input.metadata)
            ? input.metadata
            : {}),
          requestId: currentRequestId() ?? null,
          idempotencyKey: input.idempotencyKey ?? null,
          result: input.result ?? 'SUCCESS',
          statusVersion: input.statusVersion ?? 1,
        },
      },
    });
  }

  async findReplayResult<T>(
    idempotencyKey: string,
    tx?: Prisma.TransactionClient,
  ): Promise<T | undefined> {
    const log = await (tx ?? this.prisma).auditLog.findFirst({
      where: {
        metadata: {
          path: ['idempotencyKey'],
          equals: idempotencyKey,
        },
      },
      orderBy: { createdAt: 'asc' },
      select: { metadata: true },
    });
    const metadata = log?.metadata;
    if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
      return undefined;
    }
    return (metadata as Record<string, unknown>).replayResult as T | undefined;
  }
  async listLogs(
    page: number,
    pageSize: number,
    filters?: {
      actorId?: string;
      action?: string;
      resource?: string;
      resourceId?: string;
      requestId?: string;
      idempotencyKey?: string;
      result?: string;
      dateFrom?: string;
      dateTo?: string;
    },
  ) {
    const where: Prisma.AuditLogWhereInput = {
      AND: [
        ...(filters?.requestId
          ? [
              {
                metadata: {
                  path: ['requestId'],
                  equals: filters.requestId.trim(),
                },
              },
            ]
          : []),
        ...(filters?.idempotencyKey
          ? [
              {
                metadata: {
                  path: ['idempotencyKey'],
                  equals: filters.idempotencyKey.trim(),
                },
              },
            ]
          : []),
        ...(filters?.result
          ? [{ metadata: { path: ['result'], equals: filters.result.trim() } }]
          : []),
      ],

      ...(filters?.actorId
        ? {
            actorId: filters.actorId,
          }
        : {}),
      ...(filters?.action
        ? {
            action: {
              contains: filters.action.trim(),
              mode: 'insensitive',
            },
          }
        : {}),
      ...(filters?.resource
        ? {
            resource: {
              contains: filters.resource.trim(),
              mode: 'insensitive',
            },
          }
        : {}),
      ...(filters?.resourceId
        ? {
            resourceId: filters.resourceId.trim(),
          }
        : {}),
      ...(filters?.requestId
        ? {
            metadata: {
              path: ['requestId'],
              equals: filters.requestId.trim(),
            },
          }
        : {}),
      ...(filters?.idempotencyKey
        ? {
            metadata: {
              path: ['idempotencyKey'],
              equals: filters.idempotencyKey.trim(),
            },
          }
        : {}),
      ...(filters?.result
        ? {
            metadata: {
              path: ['result'],
              equals: filters.result.trim(),
            },
          }
        : {}),
      ...(filters?.dateFrom || filters?.dateTo
        ? {
            createdAt: {
              ...(filters.dateFrom
                ? {
                    gte: new Date(filters.dateFrom),
                  }
                : {}),
              ...(filters.dateTo
                ? {
                    lte: new Date(filters.dateTo),
                  }
                : {}),
            },
          }
        : {}),
    };

    const skip = (page - 1) * pageSize;

    const [total, data] = await this.prisma.$transaction([
      this.prisma.auditLog.count({
        where,
      }),
      this.prisma.auditLog.findMany({
        where,
        include: {
          actor: {
            select: {
              id: true,
              fullName: true,
              phone: true,
              role: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: pageSize,
      }),
    ]);

    return {
      page,
      pageSize,
      total,
      totalPages: Math.ceil(total / pageSize),
      filters: {
        actorId: filters?.actorId ?? null,
        action: filters?.action ?? null,
        resource: filters?.resource ?? null,
        resourceId: filters?.resourceId ?? null,
        requestId: filters?.requestId ?? null,
        idempotencyKey: filters?.idempotencyKey ?? null,
        result: filters?.result ?? null,
        dateFrom: filters?.dateFrom ?? null,
        dateTo: filters?.dateTo ?? null,
      },
      data,
    };
  }
}
