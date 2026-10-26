import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type IssueRow = {
  entityId: string | null;
  summary: string;
  details: Prisma.JsonValue | null;
};

const CHECKS: ReadonlyArray<{
  checkType: string;
  entityType: string;
  query: Prisma.Sql;
}> = [
  {
    checkType: 'CASH_LEDGER_BALANCE',
    entityType: 'ACCOUNT',
    query: Prisma.sql`
      SELECT a.id AS "entityId", 'Account cash differs from latest completed ledger balance' AS summary,
        jsonb_build_object('cashBalance', a."cashBalance", 'ledgerBalance', l."balanceAfter") AS details
      FROM accounts a
      JOIN LATERAL (
        SELECT t."balanceAfter" FROM account_transactions t
        WHERE t."accountId" = a.id AND t.status = 'COMPLETED'
        ORDER BY t."createdAt" DESC, t.id DESC LIMIT 1
      ) l ON true
      WHERE a."cashBalance" <> l."balanceAfter"`,
  },
  {
    checkType: 'FROZEN_CASH_BUY_ORDERS',
    entityType: 'ACCOUNT',
    query: Prisma.sql`
      SELECT a.id AS "entityId", 'Frozen cash differs from active BUY orders' AS summary,
        jsonb_build_object('frozenBalance', a."frozenBalance", 'orderFrozen', COALESCE(SUM(o."frozenAmount"), 0)) AS details
      FROM accounts a LEFT JOIN orders o ON o."accountId" = a.id AND o.side = 'BUY' AND o.status IN ('OPEN', 'PARTIALLY_FILLED')
      GROUP BY a.id HAVING a."frozenBalance" <> COALESCE(SUM(o."frozenAmount"), 0)`,
  },
  {
    checkType: 'FROZEN_POSITION_SELL_ORDERS',
    entityType: 'POSITION',
    query: Prisma.sql`
      SELECT p.id AS "entityId", 'Frozen quantity differs from active SELL orders' AS summary,
        jsonb_build_object('frozenQuantity', p."frozenQuantity", 'orderQuantity', COALESCE(SUM(o.quantity - o."filledQuantity"), 0)) AS details
      FROM positions p LEFT JOIN orders o ON o."accountId" = p."accountId" AND o."instrumentId" = p."instrumentId"
        AND o.side = 'SELL' AND o.status IN ('OPEN', 'PARTIALLY_FILLED')
      GROUP BY p.id HAVING p."frozenQuantity" <> COALESCE(SUM(o.quantity - o."filledQuantity"), 0)`,
  },
  {
    checkType: 'TRADE_ORDER_FILL_QUANTITY',
    entityType: 'ORDER',
    query: Prisma.sql`
      SELECT o.id AS "entityId", 'Order filled quantity differs from trade quantity' AS summary,
        jsonb_build_object('filledQuantity', o."filledQuantity", 'tradeQuantity', COALESCE(SUM(t.quantity), 0)) AS details
      FROM orders o LEFT JOIN trades t ON t."orderId" = o.id
      GROUP BY o.id HAVING o."filledQuantity" <> COALESCE(SUM(t.quantity), 0)`,
  },
  {
    checkType: 'DUPLICATE_IDEMPOTENCY_KEY',
    entityType: 'ACCOUNT_TRANSACTION',
    query: Prisma.sql`
      SELECT MIN(id) AS "entityId", 'Duplicate transaction idempotency key detected' AS summary,
        jsonb_build_object('idempotencyKey', "idempotencyKey", 'count', COUNT(*)) AS details
      FROM account_transactions WHERE "idempotencyKey" IS NOT NULL
      GROUP BY "idempotencyKey" HAVING COUNT(*) > 1`,
  },
];

@Injectable()
export class ReconciliationService {
  constructor(private readonly prisma: PrismaService) {}

  listRuns(page = 1, pageSize = 25) {
    const take = Math.min(Math.max(pageSize, 1), 100);
    const skip = (Math.max(page, 1) - 1) * take;
    return this.prisma.$transaction(async (tx) => {
      const [items, total] = await Promise.all([
        tx.reconciliationRun.findMany({
          orderBy: { startedAt: 'desc' },
          skip,
          take,
          include: { _count: { select: { issues: true } } },
        }),
        tx.reconciliationRun.count(),
      ]);
      return { items, total, page: Math.max(page, 1), pageSize: take };
    });
  }

  async getRun(id: string) {
    const run = await this.prisma.reconciliationRun.findUnique({
      where: { id },
      include: {
        issues: { orderBy: [{ acknowledgedAt: 'asc' }, { createdAt: 'desc' }] },
      },
    });
    if (!run) throw new NotFoundException('Reconciliation run not found');
    return run;
  }

  async acknowledge(issueId: string, actorId: string, note: string) {
    const trimmed = note.trim();
    if (trimmed.length < 3 || trimmed.length > 500) {
      throw new BadRequestException(
        'Acknowledgement note must be 3-500 characters',
      );
    }
    try {
      return await this.prisma.reconciliationIssue.update({
        where: { id: issueId },
        data: {
          acknowledgedAt: new Date(),
          acknowledgedBy: actorId,
          acknowledgeNote: trimmed,
        },
      });
    } catch (error: unknown) {
      if (
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        (error as { code?: unknown }).code === 'P2025'
      ) {
        throw new NotFoundException('Reconciliation issue not found');
      }
      throw error;
    }
  }

  async run(): Promise<{
    skipped: boolean;
    runId: string;
    issueCount: number;
  }> {
    const startedAt = new Date();
    const run = await this.prisma.reconciliationRun.create({
      data: { startedAt },
    });
    try {
      const result = await this.prisma.$transaction(async (tx) => {
        const lock = await tx.$queryRaw<Array<{ locked: boolean }>>(
          Prisma.sql`SELECT pg_try_advisory_xact_lock(78234119) AS locked`,
        );
        if (!lock[0]?.locked) {
          await tx.reconciliationRun.update({
            where: { id: run.id },
            data: {
              status: 'SKIPPED',
              completedAt: new Date(),
              durationMs: Date.now() - startedAt.getTime(),
            },
          });
          return { skipped: true, runId: run.id, issueCount: 0 };
        }

        let issueCount = 0;
        for (const check of CHECKS) {
          const rows = await tx.$queryRaw<IssueRow[]>(check.query);
          if (rows.length) {
            await tx.reconciliationIssue.createMany({
              data: rows.map((row) => ({
                runId: run.id,
                checkType: check.checkType,
                entityType: check.entityType,
                entityId: row.entityId,
                summary: row.summary,
                details: row.details ?? Prisma.JsonNull,
              })),
            });
            issueCount += rows.length;
          }
        }
        await tx.reconciliationRun.update({
          where: { id: run.id },
          data: {
            status: 'COMPLETED',
            completedAt: new Date(),
            durationMs: Date.now() - startedAt.getTime(),
            issueCount,
          },
        });
        return { skipped: false, runId: run.id, issueCount };
      });
      return result;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      await this.prisma.reconciliationRun.update({
        where: { id: run.id },
        data: {
          status: 'FAILED',
          completedAt: new Date(),
          durationMs: Date.now() - startedAt.getTime(),
          errorSummary: message.slice(0, 500),
        },
      });
      throw error;
    }
  }
}
