import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ApprovalService } from './approval.service';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('admin/approvals')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class ApprovalController {
  constructor(private readonly service: ApprovalService) {}
  @Get() list(@Query('status') status?: 'PENDING' | 'APPROVED' | 'REJECTED') {
    return this.service.list(status);
  }
  @Post(':id/decision') decide(
    @Param('id') id: string,
    @Req() req: AuthenticatedRequest,
    @Body() body: { decision: 'APPROVED' | 'REJECTED'; note?: string },
  ) {
    return this.service.decide(id, req.user.userId, body.decision, body.note);
  }
}
