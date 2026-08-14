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
import { DepositService } from './deposit.service';

@Controller('deposit')
@UseGuards(JwtAuthGuard, RolesGuard)
export class DepositController {
  constructor(private readonly depositService: DepositService) {}

  @Post('request')
  @Roles(UserRole.CLIENT)
  createRequest() {
    throw new BadRequestException(
      'Please contact online support for deposit instructions. Finance will credit your account after payment is confirmed.',
    );
  }

  @Post('support-submit')
  @Roles(UserRole.SUPPORT)
  submitToFinance(
    @Req() req: any,
    @Body() body: { conversationId?: string; amount?: string; referenceId?: string; paymentMethod?: string; note?: string },
  ) {
    return this.depositService.submitToFinanceBySupport(req.user.userId, body);
  }

  @Get('me')
  @Roles(UserRole.CLIENT)
  myDeposits(@Req() req: any) {
    return this.depositService.myDeposits(req.user.userId);
  }

  @Get('pending')
  @Roles(UserRole.FINANCE)
  listPending() {
    return this.depositService.listPendingDeposits();
  }

  @Patch(':id/approve')
  @Roles(UserRole.FINANCE)
  approve(@Param('id') id: string, @Req() req: any) {
    return this.depositService.approveDeposit(id, req.user.userId);
  }

  @Patch(':id/reject')
  @Roles(UserRole.FINANCE)
  reject(@Param('id') id: string, @Body() body: { note?: string }, @Req() req: any) {
    return this.depositService.rejectDeposit(id, body.note, req.user.userId);
  }
}
