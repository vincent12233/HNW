import { BadRequestException } from '@nestjs/common';
import { OrderSide, Prisma } from '../generated/prisma/client';
import { CommissionService } from './commission.service';
import { FreezeService } from './freeze.service';
import { OrderSubmissionService } from './order-submission.service';
import { CalculatorService } from './calculator.service';
import { SettlementService } from './settlement.service';

describe('Current trading path, fees, and ledger keys', () => {
  it('keeps brokerage and tax fees at zero', () => {
    const fees = new CommissionService().calculateFees(
      new Prisma.Decimal('100000.00'),
    );
    expect(fees.toFixed(2)).toBe('0.00');
  });

  it('keeps the current weighted average price and realized PnL formulas', () => {
    const calculator = new CalculatorService();
    expect(
      calculator
        .calculateAveragePrice(
          new Prisma.Decimal('100'),
          10,
          new Prisma.Decimal('120'),
          10,
        )
        .toFixed(4),
    ).toBe('110.0000');
    expect(
      calculator
        .calculateRealizedPnl(
          new Prisma.Decimal('125'),
          new Prisma.Decimal('100'),
          4,
        )
        .toFixed(2),
    ).toBe('100.00');
  });

  it('writes ORDER_FREEZE with the current idempotency key when buying', async () => {
    const service = new FreezeService();
    const tx = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          buyingPower: new Prisma.Decimal('1000'),
          cashBalance: new Prisma.Decimal('1000'),
          frozenBalance: new Prisma.Decimal(0),
        }),
        update: jest.fn(),
      },
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'ledger-1' }),
      },
    } as never;
    await service.freezeBuy(
      tx,
      'acct-1',
      new Prisma.Decimal('1000'),
      new Prisma.Decimal('250'),
      'order-9',
      'freeze buy',
    );
    expect(tx.accountTransaction.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        type: 'ORDER_FREEZE',
        idempotencyKey: 'ORDER:order-9:FREEZE',
        referenceId: 'ORDER:order-9:FREEZE',
      }),
    });
  });

  it('freezes sell quantity on the position and does not write a cash freeze', async () => {
    const service = new FreezeService();
    const tx = {
      position: {
        findUnique: jest.fn().mockResolvedValue({
          quantity: 10,
          frozenQuantity: 1,
        }),
        update: jest.fn(),
      },
      accountTransaction: { create: jest.fn() },
    } as never;
    await service.freezeSell(tx, 'pos-1', 3);
    expect(tx.position.update).toHaveBeenCalledWith({
      where: { id: 'pos-1' },
      data: { frozenQuantity: { increment: 3 } },
    });
    expect(tx.accountTransaction.create).not.toHaveBeenCalled();
  });

  it('writes TRADE_SETTLEMENT with the current idempotency key', async () => {
    const service = new SettlementService(new CalculatorService());
    const tx = {
      account: {
        update: jest.fn().mockResolvedValue({
          cashBalance: new Prisma.Decimal('750'),
        }),
      },
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'ledger-3' }),
      },
      position: { upsert: jest.fn() },
    };
    await service.settleImmediateTrade(tx as never, {
      account: {
        id: 'acct-1',
        cashBalance: new Prisma.Decimal('1000'),
        buyingPower: new Prisma.Decimal('1000'),
        frozenBalance: new Prisma.Decimal(0),
      } as never,
      instrument: { id: 'inst', exchange: 'NSE', symbol: 'TCS' } as never,
      existingPosition: null,
      orderId: 'order-9',
      side: OrderSide.BUY,
      quantity: 1,
      fillPrice: new Prisma.Decimal('250'),
      netAmount: new Prisma.Decimal('250'),
    });
    expect(tx.accountTransaction.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        type: 'TRADE_SETTLEMENT',
        idempotencyKey: 'ORDER:order-9:SETTLEMENT',
        referenceId: 'ORDER:order-9:SETTLEMENT',
      }),
    });
  });

  it('writes ORDER_RELEASE with the current idempotency key', async () => {
    const service = new FreezeService();
    const tx = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          frozenBalance: new Prisma.Decimal('250'),
        }),
        update: jest.fn(),
      },
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'ledger-2' }),
      },
    } as never;
    await service.releaseBuy(
      tx,
      'acct-1',
      new Prisma.Decimal('1000'),
      new Prisma.Decimal('250'),
      'order-9',
      'release buy',
    );
    expect(tx.accountTransaction.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        type: 'ORDER_RELEASE',
        idempotencyKey: 'ORDER:order-9:RELEASE',
      }),
    });
  });

  function submission(overrides?: {
    shouldExecuteImmediately?: boolean;
    marketOpen?: boolean;
  }) {
    const tradingService = { executeImmediately: jest.fn() };
    const limitOrderService = { createOpenLimitOrder: jest.fn() };
    const matchingService = { matchOrder: jest.fn() };
    const orderPreparation = {
      validateOrderRequest: jest.fn(),
      prepare: jest.fn().mockResolvedValue({
        idempotentReplay: false,
        account: { id: 'acct' },
        instrument: { id: 'inst' },
        clientOrderId: 'cid-1',
        limitPrice: new Prisma.Decimal('100'),
        marketPrice: new Prisma.Decimal('99.5'),
        shouldExecuteImmediately: overrides?.shouldExecuteImmediately ?? false,
      }),
      getIdempotentOrder: jest.fn(),
    };
    const service = new OrderSubmissionService(
      { $transaction: jest.fn(async (fn: (tx: object) => unknown) => fn({})) } as never,
      matchingService as never,
      tradingService as never,
      orderPreparation as never,
      limitOrderService as never,
      {
        isNormalMarketOpen: jest
          .fn()
          .mockReturnValue(overrides?.marketOpen ?? true),
      } as never,
    );
    return {
      service,
      tradingService,
      limitOrderService,
      matchingService,
      orderPreparation,
    };
  }

  it('sends currently marketable orders through immediate execution, not freeze', async () => {
    const { service, tradingService, limitOrderService, matchingService } =
      submission({ shouldExecuteImmediately: true });
    tradingService.executeImmediately.mockResolvedValue({
      id: 'o1',
      status: 'FILLED',
    });
    await service.submit('user-1', { quantity: 1 } as never);
    expect(tradingService.executeImmediately).toHaveBeenCalled();
    expect(limitOrderService.createOpenLimitOrder).not.toHaveBeenCalled();
    expect(matchingService.matchOrder).not.toHaveBeenCalled();
  });

  it('opens a DAY limit order through freeze and does not immediately match', async () => {
    const { service, tradingService, limitOrderService, matchingService } =
      submission({ shouldExecuteImmediately: false });
    limitOrderService.createOpenLimitOrder.mockResolvedValue({
      id: 'o2',
      status: 'OPEN',
      timeInForce: 'DAY',
    });
    await service.submit('user-1', { quantity: 1 } as never);
    expect(limitOrderService.createOpenLimitOrder).toHaveBeenCalled();
    expect(matchingService.matchOrder).not.toHaveBeenCalled();
    expect(tradingService.executeImmediately).not.toHaveBeenCalled();
  });

  it('matches an OPEN non-DAY limit after it is created', async () => {
    const { service, limitOrderService, matchingService, tradingService } =
      submission({ shouldExecuteImmediately: false });
    limitOrderService.createOpenLimitOrder.mockResolvedValue({
      id: 'o3',
      status: 'OPEN',
      timeInForce: 'IOC',
    });
    matchingService.matchOrder.mockResolvedValue({
      id: 'o3',
      status: 'CANCELLED',
    });
    await service.submit('user-1', { quantity: 1 } as never);
    expect(matchingService.matchOrder).toHaveBeenCalledWith('o3');
    expect(tradingService.executeImmediately).not.toHaveBeenCalled();
  });

  it('rejects a new order when the current market-hours check is closed', async () => {
    const { service, tradingService, limitOrderService } = submission({
      marketOpen: false,
    });
    await expect(service.submit('user-1', { quantity: 1 } as never)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(tradingService.executeImmediately).not.toHaveBeenCalled();
    expect(limitOrderService.createOpenLimitOrder).not.toHaveBeenCalled();
  });
});
