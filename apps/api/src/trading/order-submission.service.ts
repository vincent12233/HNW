import {
  BadRequestException,
  ConflictException,
  Injectable,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { MarketSessionService } from '../market-session/market-session.service';
import { MatchingService } from '../matching/matching.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOrderDto } from '../orders/dto/create-order.dto';
import { LimitOrderService } from './limit-order.service';
import { OrderPreparationService } from './order-preparation.service';
import { TradingService } from './trading.service';

@Injectable()
export class OrderSubmissionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly matchingService: MatchingService,
    private readonly tradingService: TradingService,
    private readonly orderPreparation: OrderPreparationService,
    private readonly limitOrderService: LimitOrderService,
    private readonly marketSession: MarketSessionService,
  ) {}

  async submit(userId: string, dto: CreateOrderDto) {
    this.orderPreparation.validateOrderRequest(dto);

    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        const result = await this.prisma.$transaction(
          async (tx) => {
            const prepared = await this.orderPreparation.prepare(
              tx,
              userId,
              dto,
            );

            if (prepared.idempotentReplay) {
              return {
                idempotentReplay: true,
                order: prepared.existingOrder,
              };
            }

            if (!this.marketSession.isNormalMarketOpen()) {
              throw new BadRequestException(
                'Market is closed. Orders can be placed during normal market hours.',
              );
            }

            const {
              account,
              instrument,
              clientOrderId,
              limitPrice,
              marketPrice,
              shouldExecuteImmediately,
            } = prepared;

            if (shouldExecuteImmediately) {
              const order = await this.tradingService.executeImmediately(
                tx,
                account,
                instrument,
                dto,
                clientOrderId,
                marketPrice,
              );

              return { idempotentReplay: false, order };
            }

            const order = await this.limitOrderService.createOpenLimitOrder(
              tx,
              account,
              instrument,
              dto,
              clientOrderId,
              limitPrice,
            );

            return { idempotentReplay: false, order };
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );

        if (
          !result.idempotentReplay &&
          result.order.status === 'OPEN' &&
          result.order.timeInForce !== 'DAY'
        ) {
          const matchedOrder = await this.matchingService.matchOrder(
            result.order.id,
          );

          return { ...result, order: matchedOrder ?? result.order };
        }

        return result;
      } catch (error: unknown) {
        if (this.hasPrismaCode(error, 'P2034') && attempt < 3) {
          continue;
        }

        if (this.hasPrismaCode(error, 'P2002')) {
          return this.orderPreparation.getIdempotentOrder(
            this.prisma,
            userId,
            dto,
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
