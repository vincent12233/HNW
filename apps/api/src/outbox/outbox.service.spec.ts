import { OutboxService } from './outbox.service';

describe('OutboxService', () => {
  it('enqueues the complete versioned envelope in the caller transaction', async () => {
    const tx = { outboxEvent: { create: jest.fn().mockResolvedValue({}) } };
    const service = new OutboxService({} as never);
    const occurredAt = new Date('2026-10-25T00:00:00Z');

    await service.enqueue(tx as never, {
      eventId: 'event-1',
      type: 'notification.requested',
      aggregateType: 'ORDER',
      aggregateId: 'order-1',
      aggregateVersion: 2,
      occurredAt,
      correlationId: 'request-1',
      payload: { userId: 'user-1' },
    });

    expect(tx.outboxEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        eventId: 'event-1',
        schemaVersion: 1,
        aggregateVersion: 2,
        occurredAt,
      }),
    });
  });

  it('propagates duplicate event errors so the surrounding transaction rolls back', async () => {
    const duplicate = { code: 'P2002' };
    const tx = {
      outboxEvent: { create: jest.fn().mockRejectedValue(duplicate) },
    };
    const service = new OutboxService({} as never);

    await expect(
      service.enqueue(tx as never, {
        eventId: 'event-1',
        type: 'notification.requested',
        aggregateType: 'ORDER',
        aggregateId: 'order-1',
        aggregateVersion: 1,
        occurredAt: new Date(),
        payload: {},
      }),
    ).rejects.toBe(duplicate);
  });
});
