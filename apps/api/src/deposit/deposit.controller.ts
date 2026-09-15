import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../auth/roles.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { DedicatedOperatorScopeGuard } from '../business/dedicated-operator-scope.guard';
import { AppContentService } from '../app-content/app-content.service';
import { DepositService } from './deposit.service';
import { SupportDepositSubmitDto } from './dto/support-deposit-submit.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('deposit')
@UseGuards(JwtAuthGuard, RolesGuard, DedicatedOperatorScopeGuard)
export class DepositController {
  constructor(
    private readonly depositService: DepositService,
    private readonly appContent: AppContentService,
  ) {}

  @Post('request')
  @Roles(UserRole.CLIENT)
  async createRequest(@Req() req: AuthenticatedRequest) {
    const header = String(req.headers['accept-language'] || 'en')
      .split(',')[0]
      .trim()
      .toLowerCase();
    const locale = header.startsWith('hi') ? 'hi' : 'en';
    throw new BadRequestException(
      await this.appContent.getDepositRejectMessage(locale),
    );
  }

  @Post('support-submit')
  @Roles(UserRole.SUPPORT)
  supportSubmit(
    @Req() req: AuthenticatedRequest,
    @Body() body: SupportDepositSubmitDto,
  ) {
    return this.depositService.submitToFinanceBySupport(req.user.userId, body);
  }

  @Get('me')
  @Roles(UserRole.CLIENT)
  myDeposits(@Req() req: AuthenticatedRequest) {
    return this.depositService.myDeposits(req.user.userId);
  }

  @Get('pending')
  @Roles(UserRole.FINANCE, UserRole.SUPPORT)
  listPending(@Req() req: AuthenticatedRequest) {
    return this.depositService.listPendingDeposits(
      req.user.role,
      req.user.userId,
    );
  }

  @Get('history')
  @Roles(UserRole.FINANCE, UserRole.SUPPORT)
  listHistory(
    @Req() req: AuthenticatedRequest,
    @Query('status') status?: string,
  ) {
    return this.depositService.listDepositHistory(
      req.user.role,
      req.user.userId,
      status,
    );
  }

  @Patch(':id/approve')
  @Roles(UserRole.FINANCE, UserRole.SUPPORT)
  approve(@Param('id') id: string, @Req() req: AuthenticatedRequest) {
    return this.depositService.approveDeposit(
      id,
      req.user.userId,
      req.user.role,
    );
  }

  @Patch(':id/reject')
  @Roles(UserRole.FINANCE, UserRole.SUPPORT)
  reject(
    @Param('id') id: string,
    @Body() body: { note?: string },
    @Req() req: AuthenticatedRequest,
  ) {
    return this.depositService.rejectDeposit(
      id,
      body.note,
      req.user.userId,
      req.user.role,
    );
  }
}
