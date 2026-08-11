import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { CreateOrderDto } from '../orders/dto/create-order.dto';
import { FreezeService } from './freeze.service';

type OrderWithDetails = Prisma.OrderGetPayload<{
  include: { instrument: true; trades: true };
}>;

@Injectable()
export class LimitOrderService {
  constructor(private readonly freezeService: FreezeService) {}

  async createOpenLimitOrder(
    tx: Prisma.TransactionClient,
    account: Prisma.AccountGetPayload<object>,
    instrument: Prisma.InstrumentGetPayload<{ include: { quote: true } }>,
    dto: CreateOrderDto,
    clientOrderId: string,
    limitPrice: Prisma.Decimal | null,
  ): Promise<OrderWithDetails> {
    if (!limitPrice) {
      throw new BadRequestException(
        'limitPrice is required for an open limit order',
      );
    }

    if (dto.side === 'BUY') {
      const frozenAmount = limitPrice.mul(dto.quantity).toDecimalPlaces(2);
      const order = await tx.order.create({
        data: {
          clientOrderId,
          accountId: account.id,
          instrumentId: instrument.id,
          side: dto.side,
          type: 'LIMIT',
          timeInForce: dto.timeInForce,
          status: 'OPEN',
          quantity: dto.quantity,
          limitPrice,
          frozenAmount,
        },
      });

      await this.freezeService.freezeBuy(
        tx,
        account.id,
        account.cashBalance,
        frozenAmount,
        order.id,
        `Funds reserved for BUY limit order ${instrument.exchange}:${instrument.symbol}`,
      );

      return tx.order.findUniqueOrThrow({
        where: { id: order.id },
        include: { instrument: true, trades: true },
      });
    }

    const position = await tx.position.findUnique({
      where: {
        accountId_instrumentId: {
          accountId: account.id,
          instrumentId: instrument.id,
        },
      },
    });

    if (!position) {
      throw new BadRequestException('Insufficient available position');
    }

    const order = await tx.order.create({
      data: {
        clientOrderId,
        accountId: account.id,
        instrumentId: instrument.id,
        side: dto.side,
        type: 'LIMIT',
        timeInForce: dto.timeInForce,
        status: 'OPEN',
        quantity: dto.quantity,
        limitPrice,
        frozenAmount: new Prisma.Decimal(0),
      },
    });

    await this.freezeService.freezeSell(tx, position.id, dto.quantity);

    return tx.order.findUniqueOrThrow({
      where: { id: order.id },
      include: { instrument: true, trades: true },
    });
  }
}
