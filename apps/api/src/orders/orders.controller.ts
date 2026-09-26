import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { BUSINESS_ERROR_CODES } from '../common/business-error-codes';
import { optionalIdempotencyKey } from '../common/idempotency-key';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { CreateOrderDto } from './dto/create-order.dto';
import { ListOrdersQueryDto } from './dto/list-orders-query.dto';
import { ListTradesQueryDto } from './dto/list-trades-query.dto';
import { ListPositionsQueryDto } from './dto/list-positions-query.dto';
import { TradingOrdersService } from './trading-orders.service';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('orders')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CLIENT)
export class OrdersController {
  constructor(private readonly ordersService: TradingOrdersService) {}

  @Post()
  createOrder(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateOrderDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    const normalizedKey = optionalIdempotencyKey(idempotencyKey);
    if (normalizedKey && normalizedKey !== dto.clientOrderId) {
      throw new BadRequestException({
        code: BUSINESS_ERROR_CODES.ORDER_IDEMPOTENCY_CONFLICT,
        message:
          'Idempotency-Key must match clientOrderId for order submission',
      });
    }
    return this.ordersService.createOrder(request.user.userId, {
      ...dto,
      clientOrderId: normalizedKey ?? dto.clientOrderId,
    });
  }

  @Get()
  listOrders(
    @Req() request: AuthenticatedRequest,
    @Query() query: ListOrdersQueryDto,
  ) {
    return this.ordersService.listOrders(request.user.userId, query);
  }

  @Get('positions')
  listPositions(
    @Req() request: AuthenticatedRequest,
    @Query() query: ListPositionsQueryDto,
  ) {
    return this.ordersService.listPositions(request.user.userId, query);
  }

  @Get('positions/:exchange/:symbol')
  getPosition(
    @Req() request: AuthenticatedRequest,
    @Param('exchange') exchange: string,
    @Param('symbol') symbol: string,
  ) {
    return this.ordersService.getPosition(
      request.user.userId,
      exchange,
      symbol,
    );
  }

  @Get('trades')
  listTrades(
    @Req() request: AuthenticatedRequest,
    @Query() query: ListTradesQueryDto,
  ) {
    return this.ordersService.listTrades(request.user.userId, query);
  }

  @Get(':orderId')
  getOrder(
    @Req() request: AuthenticatedRequest,
    @Param('orderId') orderId: string,
  ) {
    return this.ordersService.getOrder(request.user.userId, orderId);
  }

  @Post(':orderId/cancel')
  cancelOrder(
    @Req() request: AuthenticatedRequest,
    @Param('orderId') orderId: string,
  ) {
    return this.ordersService.cancelOrder(request.user.userId, orderId);
  }
}
