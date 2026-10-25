import { OutboxWorker } from './outbox.worker';

const event = (attempts = 0) => ({
  id: 'row-1',
  eventId: 'event-1',
  type: 'notification.requested',
  aggregateType: 'ORDER',
  aggregateId: 'order-1',
  aggregateVersion: 1,
  schemaVersion: 1,
  occurredAt: new Date(),
  correlationId: null,
  payload: { userId: 'user-1', type: 'ORDER', title: 'Filled', body: 'Done' },
  status: 'PROCESSING',
  attempts,
  availableAt: new Date(),
  leasedUntil: new Date(),
  processedAt: null,
  lastError: null,
  createdAt: new Date(),
  updatedAt: new Date(),
});

describe('OutboxWorker', () => {
  it('delivers a notification idempotently and marks the event processed', async () => {
    const prisma = {
      $queryRaw: jest.fn().mockResolvedValue([event()]),
      notification: { upsert: jest.fn().mockResolvedValue({}) },
      outboxEvent: {
        update: jest.fn().mockResolvedValue({}),
        count: jest.fn().mockResolvedValue(0),
      },
    };
    await new OutboxWorker(prisma as never).poll();
    expect(prisma.notification.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { outboxEventId: 'event-1' },
        update: {},
      }),
    );
    expect(prisma.outboxEvent.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'PROCESSED' }),
      }),
    );
  });

  it('returns a crashed delivery to pending with backoff', async () => {
    const prisma = {
      $queryRaw: jest.fn().mockResolvedValue([event(2)]),
      notification: {
        upsert: jest.fn().mockRejectedValue(new Error('provider down')),
      },
      outboxEvent: {
        update: jest.fn().mockResolvedValue({}),
        count: jest.fn().mockResolvedValue(0),
      },
    };
    await new OutboxWorker(prisma as never).poll();
    expect(prisma.outboxEvent.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'PENDING', attempts: 3 }),
      }),
    );
  });

  it('dead-letters an event after the bounded retry budget', async () => {
    const prisma = {
      $queryRaw: jest.fn().mockResolvedValue([event(7)]),
      notification: {
        upsert: jest.fn().mockRejectedValue(new Error('invalid payload')),
      },
      outboxEvent: {
        update: jest.fn().mockResolvedValue({}),
        count: jest.fn().mockResolvedValue(0),
      },
    };
    await new OutboxWorker(prisma as never).poll();
    expect(prisma.outboxEvent.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'DEAD', attempts: 8 }),
      }),
    );
  });
});
