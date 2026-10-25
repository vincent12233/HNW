import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { Prisma, OutboxEvent } from '../generated/prisma/client';
import {
  recordOperationalCounter,
  setOperationalGauge,
} from '../observability/metrics';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationRequestedPayload } from './outbox-event';

@Injectable()
export class OutboxWorker {
  private readonly logger = new Logger(OutboxWorker.name);
  private readonly maxAttempts = 8;

  constructor(private readonly prisma: PrismaService) {}

  @Cron('*/5 * * * * *', { name: 'transactional-outbox' })
  async poll(): Promise<void> {
    const events = await this.lease(50);
    for (const event of events) await this.deliver(event);
    const [pending, dead] = await Promise.all([
      this.prisma.outboxEvent.count({
        where: { status: { in: ['PENDING', 'PROCESSING'] } },
      }),
      this.prisma.outboxEvent.count({ where: { status: 'DEAD' } }),
    ]);
    setOperationalGauge('outbox_backlog', pending);
    setOperationalGauge('outbox_dead_letters', dead);
  }

  private lease(limit: number): Promise<OutboxEvent[]> {
    return this.prisma.$queryRaw<OutboxEvent[]>(Prisma.sql`
      WITH candidates AS (
        SELECT id FROM outbox_events
        WHERE "availableAt" <= NOW()
          AND (status = 'PENDING' OR (status = 'PROCESSING' AND "leasedUntil" < NOW()))
        ORDER BY "createdAt" ASC
        FOR UPDATE SKIP LOCKED
        LIMIT ${limit}
      )
      UPDATE outbox_events e
      SET status = 'PROCESSING', "leasedUntil" = NOW() + INTERVAL '30 seconds', "updatedAt" = NOW()
      FROM candidates c WHERE e.id = c.id
      RETURNING e.*`);
  }

  private async deliver(event: OutboxEvent): Promise<void> {
    try {
      await this.dispatch(event);
      await this.prisma.outboxEvent.update({
        where: { id: event.id },
        data: {
          status: 'PROCESSED',
          processedAt: new Date(),
          leasedUntil: null,
          lastError: null,
        },
      });
      recordOperationalCounter('outbox_delivered');
    } catch (error: unknown) {
      const attempts = event.attempts + 1;
      const dead = attempts >= this.maxAttempts;
      const message = error instanceof Error ? error.message : String(error);
      await this.prisma.outboxEvent.update({
        where: { id: event.id },
        data: {
          status: dead ? 'DEAD' : 'PENDING',
          attempts,
          availableAt: new Date(
            Date.now() + Math.min(300_000, 1000 * 2 ** attempts),
          ),
          leasedUntil: null,
          lastError: message.slice(0, 500),
        },
      });
      recordOperationalCounter(
        dead ? 'outbox_dead_lettered' : 'outbox_retry_scheduled',
      );
      this.logger.error(
        `Outbox event ${event.eventId} delivery failed: ${message}`,
      );
    }
  }

  private async dispatch(event: OutboxEvent): Promise<void> {
    if (event.type !== 'notification.requested') {
      throw new Error(`Unsupported outbox event type: ${event.type}`);
    }
    const payload = event.payload as NotificationRequestedPayload;
    await this.prisma.notification.upsert({
      where: { outboxEventId: event.eventId },
      create: { ...payload, outboxEventId: event.eventId },
      update: {},
    });
  }
}
