import { OrderSubmissionService } from './order-submission.service';

describe('OrderSubmissionService', () => {
  function createService(overrides?: {
    prisma?: any;
    matchingService?: any;
    tradingService?: any;
    orderPreparation?: any;
    limitOrderService?: any;
    marketSession?: any;
  }) {
    const prisma =
      overrides?.prisma ??
      ({ $transaction: jest.fn(async (fn: any) => fn({})) } as any);
    const matchingService =
      overrides?.matchingService ?? ({ matchOrder: jest.fn() } as any);
    const tradingService =
      overrides?.tradingService ?? ({ executeImmediately: jest.fn() } as any);
    const orderPreparation =
      overrides?.orderPreparation ??
      ({
        validateOrderRequest: jest.fn(),
        prepare: jest.fn(),
        getIdempotentOrder: jest.fn(),
      } as any);
    const limitOrderService =
      overrides?.limitOrderService ??
      ({ createOpenLimitOrder: jest.fn() } as any);
    const marketSession =
      overrides?.marketSession ??
      ({ isNormalMarketOpen: jest.fn().mockReturnValue(true) } as any);

    return {
      service: new OrderSubmissionService(
        prisma,
        matchingService,
        tradingService,
        orderPreparation,
        limitOrderService,
        marketSession,
      ),
      prisma,
      matchingService,
      tradingService,
      orderPreparation,
      limitOrderService,
      marketSession,
    };
  }

  beforeEach(() => jest.clearAllMocks());

  it('replays idempotent result from preparation even while market is closed', async () => {
    const order = { id: 'order-1', status: 'OPEN', timeInForce: 'DAY' };
    const orderPreparation = {
      validateOrderRequest: jest.fn(),
      prepare: jest.fn().mockResolvedValue({
        idempotentReplay: true,
        existingOrder: order,
      }),
      getIdempotentOrder: jest.fn(),
    } as any;
    const marketSession = {
      isNormalMarketOpen: jest.fn().mockReturnValue(false),
    } as any;
    const { service, tradingService, limitOrderService, matchingService } =
      createService({ orderPreparation, marketSession });

    const result = await service.submit('user-1', {} as any);

    expect(result).toEqual({ idempotentReplay: true, order });
    expect(marketSession.isNormalMarketOpen).not.toHaveBeenCalled();
    expect(tradingService.executeImmediately).not.toHaveBeenCalled();
    expect(limitOrderService.createOpenLimitOrder).not.toHaveBeenCalled();
    expect(matchingService.matchOrder).not.toHaveBeenCalled();
  });

  it('rejects a new normal order while the market is closed', async () => {
    const prepared = {
      idempotentReplay: false,
      account: {},
      instrument: {},
      clientOrderId: 'client-1',
      limitPrice: null,
      marketPrice: null,
      shouldExecuteImmediately: false,
    };
    const orderPreparation = {
      validateOrderRequest: jest.fn(),
      prepare: jest.fn().mockResolvedValue(prepared),
      getIdempotentOrder: jest.fn(),
    } as any;
    const marketSession = {
      isNormalMarketOpen: jest.fn().mockReturnValue(false),
    } as any;
    const { service, tradingService, limitOrderService } = createService({
      orderPreparation,
      marketSession,
    });

    await expect(service.submit('user-1', {} as any)).rejects.toThrow(
      'Market is closed',
    );
    expect(tradingService.executeImmediately).not.toHaveBeenCalled();
    expect(limitOrderService.createOpenLimitOrder).not.toHaveBeenCalled();
  });

  it('restarts preparation inside a fresh transaction after P2034', async () => {
    const transactions = [{ attempt: 1 }, { attempt: 2 }];
    let calls = 0;
    const prisma = {
      $transaction: jest.fn(async (fn: any) => {
        const tx = transactions[calls++];
        if (calls === 1) {
          await fn(tx);
          const error: any = new Error('serialization conflict');
          error.code = 'P2034';
          throw error;
        }
        return fn(tx);
      }),
    } as any;
    const order = { id: 'order-2', status: 'FILLED', timeInForce: 'DAY' };
    const orderPreparation = {
      validateOrderRequest: jest.fn(),
      prepare: jest
        .fn()
        .mockResolvedValueOnce({
          idempotentReplay: true,
          existingOrder: { id: 'rolled-back' },
        })
        .mockResolvedValueOnce({
          idempotentReplay: true,
          existingOrder: order,
        }),
      getIdempotentOrder: jest.fn(),
    } as any;
    const { service } = createService({ prisma, orderPreparation });

    const result = await service.submit('user-1', {} as any);

    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
    expect(orderPreparation.prepare).toHaveBeenCalledTimes(2);
    expect(orderPreparation.prepare.mock.calls[0][0]).toBe(transactions[0]);
    expect(orderPreparation.prepare.mock.calls[1][0]).toBe(transactions[1]);
    expect(result).toEqual({ idempotentReplay: true, order });
  });

  it('recovers a simultaneous duplicate P2002 as an idempotent replay without a second execution', async () => {
    const duplicate: any = new Error('unique constraint');
    duplicate.code = 'P2002';
    const prisma = {
      $transaction: jest.fn().mockRejectedValue(duplicate),
    } as any;
    const existingOrder = {
      id: 'existing-order',
      status: 'FILLED',
      timeInForce: 'DAY',
    };
    const orderPreparation = {
      validateOrderRequest: jest.fn(),
      prepare: jest.fn(),
      getIdempotentOrder: jest.fn().mockResolvedValue({
        idempotentReplay: true,
        order: existingOrder,
      }),
    } as any;
    const { service, tradingService, limitOrderService, matchingService } =
      createService({ prisma, orderPreparation });
    const dto = { clientOrderId: 'same-key' } as any;

    const result = await service.submit('user-1', dto);

    expect(orderPreparation.getIdempotentOrder).toHaveBeenCalledWith(
      prisma,
      'user-1',
      dto,
    );
    expect(result).toEqual({ idempotentReplay: true, order: existingOrder });
    expect(tradingService.executeImmediately).not.toHaveBeenCalled();
    expect(limitOrderService.createOpenLimitOrder).not.toHaveBeenCalled();
    expect(matchingService.matchOrder).not.toHaveBeenCalled();
  });

  it('does not freeze cash/holdings, create an order, or match when preparation rejects a special product', async () => {
    const orderPreparation = {
      validateOrderRequest: jest.fn(),
      prepare: jest
        .fn()
        .mockRejectedValue(
          new Error('Instrument is not available for standard market trading'),
        ),
      getIdempotentOrder: jest.fn(),
    } as any;
    const { service, tradingService, limitOrderService, matchingService } =
      createService({ orderPreparation });

    await expect(
      service.submit('user-1', {
        clientOrderId: 'bypass-1',
        exchange: 'NSE',
        symbol: 'IPOCO',
        side: 'BUY',
        type: 'MARKET',
        timeInForce: 'DAY',
        quantity: 1,
      } as any),
    ).rejects.toThrow(
      'Instrument is not available for standard market trading',
    );

    expect(tradingService.executeImmediately).not.toHaveBeenCalled();
    expect(limitOrderService.createOpenLimitOrder).not.toHaveBeenCalled();
    expect(matchingService.matchOrder).not.toHaveBeenCalled();
  });

  it('stops after three serialization conflicts instead of executing with stale state', async () => {
    const prisma = {
      $transaction: jest.fn().mockImplementation(async () => {
        const error: any = new Error('serialization conflict');
        error.code = 'P2034';
        throw error;
      }),
    } as any;
    const { service, tradingService, limitOrderService } = createService({
      prisma,
    });

    await expect(service.submit('user-1', {} as any)).rejects.toThrow(
      'serialization conflict',
    );
    expect(prisma.$transaction).toHaveBeenCalledTimes(3);
    expect(tradingService.executeImmediately).not.toHaveBeenCalled();
    expect(limitOrderService.createOpenLimitOrder).not.toHaveBeenCalled();
  });
});
