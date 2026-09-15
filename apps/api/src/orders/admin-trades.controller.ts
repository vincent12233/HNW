import { Controller, Get, Param, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminTradesService } from './admin-trades.service';
import { ListAdminTradesQueryDto } from './dto/list-admin-trades-query.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('admin/trades')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'FINANCE')
export class AdminTradesController {
  constructor(private readonly adminTradesService: AdminTradesService) {}

  @Get()
  listTrades(
    @Query() query: ListAdminTradesQueryDto,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.adminTradesService.listTrades(query, req.user.role);
  }

  @Get(':executionId')
  getTrade(
    @Param('executionId') executionId: string,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.adminTradesService.getTrade(executionId, req.user.role);
  }
}
