import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminTradesService } from './admin-trades.service';
import { ListAdminTradesQueryDto } from './dto/list-admin-trades-query.dto';

@Controller('admin/trades')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'FINANCE')
export class AdminTradesController {
  constructor(private readonly adminTradesService: AdminTradesService) {}

  @Get()
  listTrades(@Query() query: ListAdminTradesQueryDto) {
    return this.adminTradesService.listTrades(query);
  }

  @Get(':executionId')
  getTrade(@Param('executionId') executionId: string) {
    return this.adminTradesService.getTrade(executionId);
  }
}
