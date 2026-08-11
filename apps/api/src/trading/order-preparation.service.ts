import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { CreateOrderDto } from '../orders/dto/create-order.dto';
import { PrismaService } from '../prisma/prisma.service';

type OrderWithDetails = Prisma.OrderGetPayload<{
  include: { instrument: true; trades: true };
}>;

@Injectable()
export class OrderPreparationService {
  validateOrderRequest(dto: CreateOrderDto) {
    if (dto.type === 'LIMIT' && !dto.limitPrice) {
      throw new BadRequestException('limitPrice is required for LIMIT orders');
    }

    if (dto.type === 'MARKET' && dto.limitPrice !== undefined) {
      throw new BadRequestException(
        'limitPrice must not be supplied for MARKET orders',
      );
    }
  }

  async prepare(
    tx: Prisma.TransactionClient,
    userId: string,
    dto: CreateOrderDto,
  ) {
    const account = await tx.account.findUnique({ where: { userId } });
    if (!account) {
      throw new NotFoundException('Trading account not found');
    }

    if (!account.isLive) {
      throw new BadRequestException(
        'Only Trading Accounts are currently supported',
      );
    }

    const symbol = dto.symbol.trim().toUpperCase();
    const clientOrderId = dto.clientOrderId.trim();

    const existingOrder = await tx.order.findUnique({
      where: {
        accountId_clientOrderId: {
          accountId: account.id,
          clientOrderId,
        },
      },
      include: { instrument: true, trades: true },
    });

    if (existingOrder) {
      this.assertSameOrderRequest(existingOrder, dto);
      return {
        idempotentReplay: true as const,
        existingOrder,
        account,
        instrument: null,
        clientOrderId,
        limitPrice: null,
        marketPrice: null,
        shouldExecuteImmediately: false,
      };
    }

    const instrument = await tx.instrument.findUnique({
      where: {
        exchange_symbol: {
          exchange: dto.exchange,
          symbol,
        },
      },
      include: { quote: true },
    });

    if (!instrument || !instrument.isActive) {
      throw new NotFoundException('Tradable instrument not found');
    }

    if (!instrument.quote) {
      throw new BadRequestException('Market quote is unavailable');
    }

    if (instrument.currency !== account.currency) {
      throw new BadRequestException(
        'Instrument and account currencies do not match',
      );
    }

    const limitPrice = dto.limitPrice
      ? new Prisma.Decimal(dto.limitPrice)
      : null;

    if (limitPrice && !limitPrice.mod(instrument.tickSize).equals(0)) {
      throw new BadRequestException(
        `limitPrice must follow tick size ${instrument.tickSize.toString()}`,
      );
    }

    const marketPrice =
      dto.side === 'BUY'
        ? (instrument.quote.askPrice ?? instrument.quote.lastPrice)
        : (instrument.quote.bidPrice ?? instrument.quote.lastPrice);

    const shouldExecute =
      dto.type === 'MARKET' ||
      (dto.side === 'BUY' &&
        limitPrice !== null &&
        limitPrice.greaterThanOrEqualTo(marketPrice)) ||
      (dto.side === 'SELL' &&
        limitPrice !== null &&
        limitPrice.lessThanOrEqualTo(marketPrice));

    const shouldExecuteImmediately =
      shouldExecute && (dto.type === 'MARKET' || dto.timeInForce === 'DAY');

    return {
      idempotentReplay: false as const,
      existingOrder: null,
      account,
      instrument,
      clientOrderId,
      limitPrice,
      marketPrice,
      shouldExecuteImmediately,
    };
  }

  async getIdempotentOrder(
    prisma: PrismaService,
    userId: string,
    dto: CreateOrderDto,
  ) {
    const existing = await prisma.order.findFirst({
      where: {
        clientOrderId: dto.clientOrderId.trim(),
        account: { userId },
      },
      include: { instrument: true, trades: true },
    });

    if (!existing) {
      throw new ConflictException('clientOrderId has already been processed');
    }

    this.assertSameOrderRequest(existing, dto);
    return { idempotentReplay: true, order: existing };
  }

  private assertSameOrderRequest(
    existing: OrderWithDetails,
    dto: CreateOrderDto,
  ) {
    const incomingLimitPrice = dto.limitPrice
      ? new Prisma.Decimal(dto.limitPrice)
      : null;

    const sameLimitPrice =
      (existing.limitPrice === null && incomingLimitPrice === null) ||
      (existing.limitPrice !== null &&
        incomingLimitPrice !== null &&
        existing.limitPrice.equals(incomingLimitPrice));

    const matches =
      existing.instrument.exchange === dto.exchange &&
      existing.instrument.symbol === dto.symbol.trim().toUpperCase() &&
      existing.side === dto.side &&
      existing.type === dto.type &&
      existing.timeInForce === dto.timeInForce &&
      existing.quantity === dto.quantity &&
      sameLimitPrice;

    if (!matches) {
      throw new ConflictException(
        'clientOrderId is already used for a different order',
      );
    }
  }
}
