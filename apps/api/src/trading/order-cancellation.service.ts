import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { FreezeService } from './freeze.service';

@Injectable()
export class OrderCancellationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly freezeService: FreezeService,
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
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        return await this.prisma.$transaction(
          (tx) => this.cancelInTransaction(tx, orderId, userId, allowInactive),
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );
      } catch (error: unknown) {
        if (this.hasPrismaCode(error, 'P2034')) {
          if (attempt < 3) continue;
          throw new ConflictException(
            'Concurrent order update detected; please retry',
          );
        }
        throw error;
      }
    }

    throw new ConflictException(
      'Concurrent order update detected; please retry',
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
      throw new BadRequestException('Order has no remaining quantity to cancel');
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

    return { cancelled: true, order: cancelledOrder };
  }

  private hasPrismaCode(error: unknown, expectedCode: string): boolean {
    return (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      (error as { code?: unknown }).code === expectedCode
    );
  }
}
