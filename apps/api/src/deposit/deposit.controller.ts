import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../auth/roles.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { DedicatedOperatorScopeGuard } from '../business/dedicated-operator-scope.guard';
import { DepositService } from './deposit.service';

@Controller('deposit')
@UseGuards(JwtAuthGuard, RolesGuard, DedicatedOperatorScopeGuard)
export class DepositController {
  constructor(private readonly depositService: DepositService) {}

  @Post('request')
  @Roles(UserRole.CLIENT)
  createRequest() {
    throw new BadRequestException(
      'Please contact online support for deposit instructions. Finance will credit your account after payment is confirmed.',
    );
  }

  @Get('me')
  @Roles(UserRole.CLIENT)
  myDeposits(@Req() req: any) {
    return this.depositService.myDeposits(req.user.userId);
  }

  @Get('pending')
  @Roles(UserRole.FINANCE, UserRole.SUPPORT)
  listPending(@Req() req: any) {
    return this.depositService.listPendingDeposits(req.user.role, req.user.userId);
  }

  @Patch(':id/approve')
  @Roles(UserRole.FINANCE, UserRole.SUPPORT)
  approve(@Param('id') id: string, @Req() req: any) {
    return this.depositService.approveDeposit(id, req.user.userId, req.user.role);
  }

  @Patch(':id/reject')
  @Roles(UserRole.FINANCE, UserRole.SUPPORT)
  reject(@Param('id') id: string, @Body() body: { note?: string }, @Req() req: any) {
    return this.depositService.rejectDeposit(id, body.note, req.user.userId, req.user.role);
  }
}
