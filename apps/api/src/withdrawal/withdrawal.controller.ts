import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { WithdrawalService } from './withdrawal.service';

@Controller('withdrawal')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WithdrawalController {
  constructor(private readonly withdrawalService: WithdrawalService) {}

  @Post('request')
  createRequest(
    @Req() req: any,
    @Body()
    body: {
      amount: number;
      bankName?: string;
      accountNumber?: string;
      ifscCode?: string;
      upiId?: string;
      note?: string;
    },
  ) {
    return this.withdrawalService.createRequest(
      req.user.userId,
      Number(body.amount),
      body.bankName,
      body.accountNumber,
      body.ifscCode,
      body.upiId,
      body.note,
    );
  }

  @Get('me')
  myWithdrawals(@Req() req: any) {
    return this.withdrawalService.myWithdrawals(req.user.userId);
  }

  @Get('pending')
  @Roles(UserRole.ADMIN, UserRole.FINANCE)
  listPending() {
    return this.withdrawalService.listPendingWithdrawals();
  }

  @Patch(':id/approve')
  @Roles(UserRole.ADMIN, UserRole.FINANCE)
  approve(@Param('id') id: string) {
    return this.withdrawalService.approveWithdrawal(id);
  }

  @Patch(':id/reject')
  @Roles(UserRole.ADMIN, UserRole.FINANCE)
  reject(@Param('id') id: string, @Body() body: { note?: string }) {
    return this.withdrawalService.rejectWithdrawal(id, body.note);
  }
}
