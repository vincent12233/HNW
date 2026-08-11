import { OrderSubmissionService } from './order-submission.service';

describe('OrderSubmissionService', () => {
  it('replays idempotent result from preparation', async () => {
    const order = { id: 'order-1', status: 'OPEN', timeInForce: 'DAY' };
    const prisma = {
      $transaction: jest.fn(async (fn: any) => fn({})),
    } as any;
    const matchingService = { matchOrder: jest.fn() } as any;
    const tradingService = { executeImmediately: jest.fn() } as any;
    const orderPreparation = {
      validateOrderRequest: jest.fn(),
      prepare: jest.fn().mockResolvedValue({
        idempotentReplay: true,
        existingOrder: order,
      }),
      getIdempotentOrder: jest.fn(),
    } as any;
    const limitOrderService = { createOpenLimitOrder: jest.fn() } as any;

    const service = new OrderSubmissionService(
      prisma,
      matchingService,
      tradingService,
      orderPreparation,
      limitOrderService,
    );

    const result = await service.submit('user-1', {} as any);

    expect(result).toEqual({ idempotentReplay: true, order });
    expect(tradingService.executeImmediately).not.toHaveBeenCalled();
    expect(limitOrderService.createOpenLimitOrder).not.toHaveBeenCalled();
  });

  it('retries once after a serializable transaction conflict', async () => {
    const order = { id: 'order-1', status: 'FILLED', timeInForce: 'DAY' };
    let calls = 0;
    const prisma = {
      $transaction: jest.fn(async (fn: any) => {
        calls += 1;
        if (calls === 1) {
          const error: any = new Error('conflict');
          error.code = 'P2034';
          throw error;
        }
        return fn({});
      }),
    } as any;
    const matchingService = { matchOrder: jest.fn() } as any;
    const tradingService = { executeImmediately: jest.fn() } as any;
    const orderPreparation = {
      validateOrderRequest: jest.fn(),
      prepare: jest.fn().mockResolvedValue({
        idempotentReplay: true,
        existingOrder: order,
      }),
      getIdempotentOrder: jest.fn(),
    } as any;
    const limitOrderService = { createOpenLimitOrder: jest.fn() } as any;

    const service = new OrderSubmissionService(
      prisma,
      matchingService,
      tradingService,
      orderPreparation,
      limitOrderService,
    );

    const result = await service.submit('user-1', {} as any);

    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
    expect(result).toEqual({ idempotentReplay: true, order });
  });
});
