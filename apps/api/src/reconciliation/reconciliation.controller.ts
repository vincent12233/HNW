import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ReconciliationService } from './reconciliation.service';

@Controller('admin/reconciliation')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class ReconciliationController {
  constructor(private readonly reconciliation: ReconciliationService) {}

  @Get()
  list(@Query('page') page?: string, @Query('pageSize') pageSize?: string) {
    return this.reconciliation.listRuns(
      Number(page) || 1,
      Number(pageSize) || 25,
    );
  }

  @Get(':id')
  detail(@Param('id') id: string) {
    return this.reconciliation.getRun(id);
  }

  @Patch('issues/:id/acknowledge')
  acknowledge(
    @Param('id') id: string,
    @Body() body: { note?: string },
    @Req() request: { user: { id: string } },
  ) {
    return this.reconciliation.acknowledge(
      id,
      request.user.id,
      body.note ?? '',
    );
  }
}
