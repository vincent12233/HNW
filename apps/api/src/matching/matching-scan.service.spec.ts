import { MatchingScanService } from './matching-scan.service';

describe('MatchingScanService', () => {
  const config = {
    get: jest.fn((key: string) => {
      if (key === 'MATCHING_BATCH_SIZE') return '2';
      if (key === 'MATCHING_MAX_SCAN_BATCHES') return '1';
      return undefined;
    }),
  } as any;
  const openSession = { isNormalMarketOpen: jest.fn().mockReturnValue(true) } as any;

  beforeEach(() => {
    jest.clearAllMocks();
    openSession.isNormalMarketOpen.mockReturnValue(true);
  });

  it('does not scan or match while the normal market is closed', async () => {
    const prisma = { order: { findMany: jest.fn() } } as any;
    const matchingService = { matchOrder: jest.fn() } as any;
    const marketSession = { isNormalMarketOpen: jest.fn().mockReturnValue(false) } as any;
    const service = new MatchingScanService(
      prisma,
      matchingService,
      marketSession,
      config,
    );

    await service.scanOpenOrders();

    expect(prisma.order.findMany).not.toHaveBeenCalled();
    expect(matchingService.matchOrder).not.toHaveBeenCalled();
  });

  it('continues from the previous page on the next scheduler tick', async () => {
    const firstPlacedAt = new Date('2026-08-12T07:00:00.000Z');
    const secondPlacedAt = new Date('2026-08-12T07:00:01.000Z');
    const thirdPlacedAt = new Date('2026-08-12T07:00:02.000Z');
    const fourthPlacedAt = new Date('2026-08-12T07:00:03.000Z');
    const prisma = {
      order: {
        findMany: jest
          .fn()
          .mockResolvedValueOnce([
            { id: 'order-a', placedAt: firstPlacedAt },
            { id: 'order-b', placedAt: secondPlacedAt },
          ])
          .mockResolvedValueOnce([
            { id: 'order-c', placedAt: thirdPlacedAt },
            { id: 'order-d', placedAt: fourthPlacedAt },
          ]),
      },
    } as any;
    const matchingService = { matchOrder: jest.fn().mockResolvedValue(null) } as any;
    const service = new MatchingScanService(
      prisma,
      matchingService,
      openSession,
      config,
    );

    await service.scanOpenOrders();
    await service.scanOpenOrders();

    expect(matchingService.matchOrder.mock.calls.flat()).toEqual([
      'order-a',
      'order-b',
      'order-c',
      'order-d',
    ]);
    expect(prisma.order.findMany).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        where: expect.objectContaining({
          OR: [
            { placedAt: { gt: secondPlacedAt } },
            { placedAt: secondPlacedAt, id: { gt: 'order-b' } },
          ],
        }),
      }),
    );
  });

  it('continues matching later orders when one order fails', async () => {
    const prisma = {
      order: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'bad-order', placedAt: new Date('2026-08-12T07:00:00.000Z') },
          { id: 'good-order', placedAt: new Date('2026-08-12T07:00:01.000Z') },
        ]),
      },
    } as any;
    const matchingService = {
      matchOrder: jest
        .fn()
        .mockRejectedValueOnce(new Error('settlement conflict'))
        .mockResolvedValueOnce(null),
    } as any;
    const service = new MatchingScanService(
      prisma,
      matchingService,
      openSession,
      config,
    );

    await expect(service.scanOpenOrders()).resolves.toBeUndefined();

    expect(matchingService.matchOrder).toHaveBeenNthCalledWith(1, 'bad-order');
    expect(matchingService.matchOrder).toHaveBeenNthCalledWith(2, 'good-order');
  });

  it('wraps back to the beginning after reaching the end of active orders', async () => {
    const placedAt = new Date('2026-08-12T07:00:00.000Z');
    const prisma = {
      order: {
        findMany: jest
          .fn()
          .mockResolvedValueOnce([{ id: 'order-a', placedAt }])
          .mockResolvedValueOnce([{ id: 'order-a', placedAt }]),
      },
    } as any;
    const matchingService = { matchOrder: jest.fn().mockResolvedValue(null) } as any;
    const service = new MatchingScanService(
      prisma,
      matchingService,
      openSession,
      config,
    );

    await service.scanOpenOrders();
    await service.scanOpenOrders();

    expect(prisma.order.findMany).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        where: { status: { in: ['OPEN', 'PARTIALLY_FILLED'] } },
      }),
    );
  });
});
