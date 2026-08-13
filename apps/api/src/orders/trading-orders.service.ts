import { Injectable } from '@nestjs/common';
import { OrderCancellationService } from '../trading/order-cancellation.service';
import { OrderSubmissionService } from '../trading/order-submission.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { ListOrdersQueryDto } from './dto/list-orders-query.dto';
import { ListPositionsQueryDto } from './dto/list-positions-query.dto';
import { ListTradesQueryDto } from './dto/list-trades-query.dto';
import { OrdersService } from './orders.service';

@Injectable()
export class TradingOrdersService {
  constructor(
    private readonly orderSubmission: OrderSubmissionService,
    private readonly orderCancellation: OrderCancellationService,
    private readonly legacyOrdersService: OrdersService,
  ) {}

  createOrder(userId: string, dto: CreateOrderDto) {
    return this.orderSubmission.submit(userId, dto);
  }

  listOrders(userId: string, query: ListOrdersQueryDto) {
    return this.legacyOrdersService.listOrders(userId, query);
  }

  listPositions(userId: string, query: ListPositionsQueryDto) {
    return this.legacyOrdersService.listPositions(userId, query);
  }

  getPosition(userId: string, exchange: string, symbol: string) {
    return this.legacyOrdersService.getPosition(userId, exchange, symbol);
  }

  listTrades(userId: string, query: ListTradesQueryDto) {
    return this.legacyOrdersService.listTrades(userId, query);
  }

  getOrder(userId: string, orderId: string) {
    return this.legacyOrdersService.getOrder(userId, orderId);
  }

  cancelOrder(userId: string, orderId: string) {
    return this.orderCancellation.cancel(userId, orderId);
  }
}
