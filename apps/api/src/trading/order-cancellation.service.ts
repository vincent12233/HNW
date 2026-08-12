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

  async cancel(userId: string, orderId: string) {
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        return await this.prisma.$transaction(
          async (tx) => {
            const order = await tx.order.findFirst({
              where: {
                id: orderId,
                account: { userId },
              },
              include: {
                account: true,
                instrument: true,
                trades: true,
              },
            });

            if (!order) {
              throw new NotFoundException('Order not found');
            }

            if (
              order.status !== 'OPEN' &&
              order.status !== 'PARTIALLY_FILLED'
            ) {
              throw new BadRequestException(
                `Only active orders can be cancelled. Current status: ${order.status}`,
              );
            }

            const remainingQuantity = order.quantity - order.filledQuantity;
            if (remainingQuantity <= 0) {
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
                'Released funds after order cancellation',
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

              await this.freezeService.releaseSell(
                tx,
                position.id,
                remainingQuantity,
              );
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
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );
      } catch (error: unknown) {
        if (this.hasPrismaCode(error, 'P2034')) {
          if (attempt < 3) {
            continue;
          }
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

  private hasPrismaCode(error: unknown, expectedCode: string): boolean {
    return (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      (error as { code?: unknown }).code === expectedCode
    );
  }
}
