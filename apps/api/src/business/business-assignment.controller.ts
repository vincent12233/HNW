import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import type { AuthenticatedRequest } from '../auth/authenticated-request';
import { BusinessAssignmentService } from './business-assignment.service';
import {
  ListBusinessAssignmentsQueryDto,
  PreviewBusinessAssignmentDto,
  TransferBusinessAssignmentDto,
} from './business-assignment.dto';

@Controller('admin/business-assignments')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class BusinessAssignmentAdminController {
  constructor(private readonly assignments: BusinessAssignmentService) {}

  @Get()
  list(
    @Req() req: AuthenticatedRequest,
    @Query() query: ListBusinessAssignmentsQueryDto,
  ) {
    return this.assignments.listAssignments(req.user.userId, query);
  }

  @Get(':businessUserId/history')
  history(
    @Req() req: AuthenticatedRequest,
    @Param('businessUserId') businessUserId: string,
  ) {
    return this.assignments.historyForAdmin(req.user.userId, businessUserId);
  }

  @Post('preview')
  preview(
    @Req() req: AuthenticatedRequest,
    @Body() body: PreviewBusinessAssignmentDto,
  ) {
    return this.assignments.preview(req.user.userId, body);
  }

  @Post('transfer')
  transfer(
    @Req() req: AuthenticatedRequest,
    @Body() body: TransferBusinessAssignmentDto,
  ) {
    return this.assignments.assignOrTransferBusinessToManager(req.user.userId, body);
  }
}
