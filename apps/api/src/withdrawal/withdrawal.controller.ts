import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { WithdrawalService } from './withdrawal.service';
import { CreateWithdrawalRequestDto } from './dto/create-withdrawal-request.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';
import { optionalIdempotencyKey } from '../common/idempotency-key';

@Controller('withdrawal')
@UseGuards(JwtAuthGuard, RolesGuard)
export class WithdrawalController {
  constructor(private readonly withdrawalService: WithdrawalService) {}

  @Post('request')
  @Roles(UserRole.CLIENT)
  createRequest(
    @Req() req: AuthenticatedRequest,
    @Body()
    body: CreateWithdrawalRequestDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    return this.withdrawalService.createRequest(
      req.user.userId,
      body.amount,
      body.bankName,
      body.accountNumber,
      body.ifscCode,
      body.upiId,
      body.note,
      body.withdrawalPin,
      optionalIdempotencyKey(idempotencyKey),
    );
  }

  @Get('me')
  @Roles(UserRole.CLIENT)
  myWithdrawals(@Req() req: AuthenticatedRequest) {
    return this.withdrawalService.myWithdrawals(req.user.userId);
  }

  @Get('pending')
  @Roles(UserRole.ADMIN, UserRole.FINANCE)
  listPending(@Req() req: AuthenticatedRequest) {
    return this.withdrawalService.listPendingWithdrawals(req.user.role);
  }

  @Get('history')
  @Roles(UserRole.ADMIN, UserRole.FINANCE)
  listHistory(
    @Req() req: AuthenticatedRequest,
    @Query('status') status?: string,
  ) {
    return this.withdrawalService.listWithdrawalHistory(req.user.role, status);
  }

  @Patch(':id/approve')
  @Roles(UserRole.ADMIN, UserRole.FINANCE)
  approve(@Param('id') id: string, @Req() req: AuthenticatedRequest) {
    return this.withdrawalService.approveWithdrawal(
      id,
      req.user.userId,
      req.user.role,
    );
  }

  @Patch(':id/reject')
  @Roles(UserRole.ADMIN, UserRole.FINANCE)
  reject(
    @Param('id') id: string,
    @Body() body: { note?: string },
    @Req() req: AuthenticatedRequest,
  ) {
    return this.withdrawalService.rejectWithdrawal(
      id,
      body.note,
      req.user.userId,
      req.user.role,
    );
  }
}
