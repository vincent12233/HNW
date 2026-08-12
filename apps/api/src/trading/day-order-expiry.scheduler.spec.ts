import { DayOrderExpiryScheduler } from './day-order-expiry.scheduler';

describe('DayOrderExpiryScheduler', () => {
  const config = { get: jest.fn().mockReturnValue('100') } as any;

  beforeEach(() => jest.clearAllMocks());

  it('expires only DAY orders whose trading day has ended', async () => {
    const expiredAt = new Date('2026-08-11T05:00:00.000Z');
    const activeAt = new Date('2026-08-12T05:00:00.000Z');
    const prisma = {
      order: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'expired', placedAt: expiredAt },
          { id: 'active', placedAt: activeAt },
        ]),
      },
    } as any;
    const marketSession = {
      isDayOrderExpired: jest
        .fn()
        .mockImplementation((placedAt: Date) => placedAt === expiredAt),
    } as any;
    const cancellation = { expireDayOrder: jest.fn().mockResolvedValue({}) } as any;
    const scheduler = new DayOrderExpiryScheduler(
      prisma,
      marketSession,
      cancellation,
      config,
    );

    await scheduler.expireDayOrders();

    expect(cancellation.expireDayOrder).toHaveBeenCalledTimes(1);
    expect(cancellation.expireDayOrder).toHaveBeenCalledWith('expired');
    expect(marketSession.isDayOrderExpired).toHaveBeenCalledTimes(2);
  });

  it('continues expiring later orders when one expiry races or fails', async () => {
    const prisma = {
      order: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'first', placedAt: new Date('2026-08-11T05:00:00.000Z') },
          { id: 'second', placedAt: new Date('2026-08-11T05:01:00.000Z') },
        ]),
      },
    } as any;
    const marketSession = { isDayOrderExpired: jest.fn().mockReturnValue(true) } as any;
    const cancellation = {
      expireDayOrder: jest
        .fn()
        .mockRejectedValueOnce(new Error('concurrent fill'))
        .mockResolvedValueOnce({ cancelled: true }),
    } as any;
    const scheduler = new DayOrderExpiryScheduler(
      prisma,
      marketSession,
      cancellation,
      config,
    );

    await expect(scheduler.expireDayOrders()).resolves.toBeUndefined();

    expect(cancellation.expireDayOrder).toHaveBeenNthCalledWith(1, 'first');
    expect(cancellation.expireDayOrder).toHaveBeenNthCalledWith(2, 'second');
  });
});
