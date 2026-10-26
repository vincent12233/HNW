import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OutboxEventInput } from './outbox-event';

type OutboxWriter = Pick<Prisma.TransactionClient, 'outboxEvent'>;

@Injectable()
export class OutboxService {
  constructor(private readonly prisma: PrismaService) {}

  async enqueue(tx: OutboxWriter, event: OutboxEventInput): Promise<void> {
    await tx.outboxEvent.create({
      data: {
        ...event,
        schemaVersion: event.schemaVersion ?? 1,
      },
    });
  }

  async backlog(): Promise<{ pending: number; dead: number }> {
    const [pending, dead] = await Promise.all([
      this.prisma.outboxEvent.count({
        where: { status: { in: ['PENDING', 'PROCESSING'] } },
      }),
      this.prisma.outboxEvent.count({ where: { status: 'DEAD' } }),
    ]);
    return { pending, dead };
  }
}
