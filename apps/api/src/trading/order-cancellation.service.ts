import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { runSerializableTransaction } from '../common/transaction-retry';
import { PrismaService } from '../prisma/prisma.service';
import { FreezeService } from './freeze.service';
import { assertOrderTransition } from './order-state-machine';
import { OutboxService } from '../outbox/outbox.service';

@Injectable()
export class OrderCancellationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly freezeService: FreezeService,
    @Optional() private readonly outbox?: OutboxService,
  ) {}

  cancel(userId: string, orderId: string) {
    return this.cancelWithRetry(orderId, userId, false);
  }

  expireDayOrder(orderId: string) {
    return this.cancelWithRetry(orderId, undefined, true);
  }

  private async cancelWithRetry(
    orderId: string,
    userId: string | undefined,
    allowInactive: boolean,
  ) {
    return runSerializableTransaction(
      () =>
        this.prisma.$transaction(
          (tx) => this.cancelInTransaction(tx, orderId, userId, allowInactive),
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        ),
      {
        onExhausted: () =>
          new ConflictException(
            'Concurrent order update detected; please retry',
          ),
      },
    );
  }

  private async cancelInTransaction(
    tx: Prisma.TransactionClient,
    orderId: string,
    userId: string | undefined,
    allowInactive: boolean,
  ) {
    const order = await tx.order.findFirst({
      where: userId
        ? {
            id: orderId,
            account: { userId },
          }
        : { id: orderId },
      include: {
        account: true,
        instrument: true,
        trades: true,
      },
    });

    if (!order) {
      if (allowInactive) return { cancelled: false, order: null };
      throw new NotFoundException('Order not found');
    }

    if (order.status !== 'OPEN' && order.status !== 'PARTIALLY_FILLED') {
      if (allowInactive) return { cancelled: false, order };
      throw new BadRequestException(
        `Only active orders can be cancelled. Current status: ${order.status}`,
      );
    }

    const remainingQuantity = order.quantity - order.filledQuantity;
    if (remainingQuantity <= 0) {
      if (allowInactive) return { cancelled: false, order };
      throw new BadRequestException(
        'Order has no remaining quantity to cancel',
      );
    }

    if (order.side === 'BUY') {
      await this.freezeService.releaseBuy(
        tx,
        order.accountId,
        order.account.cashBalance,
        order.frozenAmount,
        order.id,
        allowInactive
          ? 'Released funds after DAY order expiry'
          : 'Released funds after order cancellation',
      );
    } else {
      const position = await tx.position.findUnique({
        where: {
          accountId_instrumentId: {
            accountId: order.accountId,
            instrumentId: order.instrumentId,
          },
        },
      });

      if (!position) {
        throw new ConflictException(
          'Position for this SELL order no longer exists',
        );
      }

      await this.freezeService.releaseSell(tx, position.id, remainingQuantity);
    }

    const now = new Date();
    assertOrderTransition(order.status, 'CANCELLED');
    const cancelledOrder = await tx.order.update({
      where: { id: order.id },
      data: {
        status: 'CANCELLED',
        frozenAmount: new Prisma.Decimal(0),
        completedAt: now,
        cancelledAt: now,
      },
      include: {
        instrument: true,
        trades: true,
      },
    });

    const notification = {
      userId: order.account.userId,
      type: 'TRADE',
      title: allowInactive ? 'DAY order expired' : 'Order cancelled',
      body: `${order.instrument?.symbol ?? 'Order'} ${order.side} order: ${remainingQuantity} remaining share${remainingQuantity === 1 ? '' : 's'} cancelled and reserved assets released.`,
      referenceId: order.id,
    };
    if (this.outbox) {
      await this.outbox.enqueue(tx, {
        eventId: `order:${order.id}:cancelled`,
        type: 'notification.requested',
        aggregateType: 'ORDER',
        aggregateId: order.id,
        aggregateVersion: order.filledQuantity,
        occurredAt: now,
        correlationId: order.id,
        payload: notification,
      });
    } else {
      await tx.notification?.create({ data: notification });
    }

    return { cancelled: true, order: cancelledOrder };
  }
}
