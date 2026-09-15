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
import { AdminAccountService } from './admin-account.service';
import { AdjustBalanceDto } from './dto/adjust-balance.dto';
import { ListAdminAccountsQueryDto } from './dto/list-admin-accounts-query.dto';
import { ListAdminAccountTransactionsQueryDto } from './dto/list-admin-account-transactions-query.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('admin/accounts')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'FINANCE')
export class AdminAccountController {
  constructor(private readonly adminAccountService: AdminAccountService) {}

  @Get()
  listAccounts(
    @Query() query: ListAdminAccountsQueryDto,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminAccountService.listAccounts(query, request.user.role);
  }

  @Get('transactions')
  listTransactions(
    @Query() query: ListAdminAccountTransactionsQueryDto,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminAccountService.listTransactions(query, request.user.role);
  }

  @Get(':accountNumber/transactions')
  getAccountTransactions(
    @Param('accountNumber') accountNumber: string,
    @Query() query: ListAdminAccountTransactionsQueryDto,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminAccountService.getAccountTransactions(
      accountNumber,
      query,
      request.user.role,
    );
  }
  @Get(':accountNumber')
  getAccount(
    @Param('accountNumber') accountNumber: string,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminAccountService.getAccount(
      accountNumber,
      request.user.role,
    );
  }

  @Post(':accountNumber/credit')
  @Roles('FINANCE', 'SUPPORT')
  credit(
    @Param('accountNumber') accountNumber: string,
    @Body() dto: AdjustBalanceDto,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminAccountService.credit(
      accountNumber,
      dto,
      request.user.userId,
      request.user.role,
    );
  }

  @Post(':accountNumber/debit')
  @Roles('FINANCE', 'SUPPORT')
  debit(
    @Param('accountNumber') accountNumber: string,
    @Body() dto: AdjustBalanceDto,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminAccountService.debit(
      accountNumber,
      dto,
      request.user.userId,
      request.user.role,
    );
  }
}
