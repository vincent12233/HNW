import { Controller, Get, Param, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminOrdersService } from './admin-orders.service';
import { ListAdminOrdersQueryDto } from './dto/list-admin-orders-query.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('admin/orders')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'FINANCE')
export class AdminOrdersController {
  constructor(private readonly adminOrdersService: AdminOrdersService) {}

  @Get()
  listOrders(
    @Query() query: ListAdminOrdersQueryDto,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.adminOrdersService.listOrders(query, req.user.role);
  }

  @Get(':orderId')
  getOrder(
    @Param('orderId') orderId: string,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.adminOrdersService.getOrder(orderId, req.user.role);
  }
}
