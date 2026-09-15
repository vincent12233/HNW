import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AccountService } from './account.service';
import { ListTransactionsQueryDto } from './dto/list-transactions-query.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('account')
@UseGuards(JwtAuthGuard)
export class AccountController {
  constructor(private readonly accountService: AccountService) {}

  @Get('me')
  getMyAccount(@Req() request: AuthenticatedRequest) {
    return this.accountService.getMyAccount(request.user.userId);
  }

  @Get('portfolio')
  getPortfolioSummary(@Req() request: AuthenticatedRequest) {
    return this.accountService.getPortfolioSummary(request.user.userId);
  }

  @Get('allocation')
  getAssetAllocation(@Req() request: AuthenticatedRequest) {
    return this.accountService.getAssetAllocation(request.user.userId);
  }

  @Get('transactions')
  getMyTransactions(
    @Req() request: AuthenticatedRequest,
    @Query() query: ListTransactionsQueryDto,
  ) {
    return this.accountService.getMyTransactions(request.user.userId, query);
  }
}
