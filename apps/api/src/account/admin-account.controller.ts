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
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminAccountService } from './admin-account.service';
import { AdjustBalanceDto } from './dto/adjust-balance.dto';
import { ListAdminAccountsQueryDto } from './dto/list-admin-accounts-query.dto';
import { ListAdminAccountTransactionsQueryDto } from './dto/list-admin-account-transactions-query.dto';
interface AuthenticatedRequest extends Request {
  user: {
    userId: string;
    phone?: string | null;
    role: string;
  };
}

@Controller('admin/accounts')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'FINANCE')
export class AdminAccountController {
  constructor(private readonly adminAccountService: AdminAccountService) {}

  @Get()
  listAccounts(@Query() query: ListAdminAccountsQueryDto) {
    return this.adminAccountService.listAccounts(query);
  }

  @Get('transactions')
  listTransactions(@Query() query: ListAdminAccountTransactionsQueryDto) {
    return this.adminAccountService.listTransactions(query);
  }

  @Get(':accountNumber/transactions')
  getAccountTransactions(
    @Param('accountNumber') accountNumber: string,
    @Query() query: ListAdminAccountTransactionsQueryDto,
  ) {
    return this.adminAccountService.getAccountTransactions(
      accountNumber,
      query,
    );
  }
  @Get(':accountNumber')
  getAccount(@Param('accountNumber') accountNumber: string) {
    return this.adminAccountService.getAccount(accountNumber);
  }

  @Post(':accountNumber/credit')
  credit(
    @Param('accountNumber') accountNumber: string,
    @Body() dto: AdjustBalanceDto,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminAccountService.credit(
      accountNumber,
      dto,
      request.user.userId,
    );
  }

  @Post(':accountNumber/debit')
  debit(
    @Param('accountNumber') accountNumber: string,
    @Body() dto: AdjustBalanceDto,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.adminAccountService.debit(
      accountNumber,
      dto,
      request.user.userId,
    );
  }
}
