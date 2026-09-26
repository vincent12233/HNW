import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { BUSINESS_ERROR_CODES } from '../common/business-error-codes';
import { optionalIdempotencyKey } from '../common/idempotency-key';
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
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    this.assertAdjustmentKey(dto.referenceId, idempotencyKey);
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
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    this.assertAdjustmentKey(dto.referenceId, idempotencyKey);
    return this.adminAccountService.debit(
      accountNumber,
      dto,
      request.user.userId,
      request.user.role,
    );
  }

  private assertAdjustmentKey(referenceId: string, header?: string) {
    const normalizedKey = optionalIdempotencyKey(header);
    if (normalizedKey && normalizedKey !== referenceId.trim()) {
      throw new BadRequestException({
        code: BUSINESS_ERROR_CODES.IDEMPOTENCY_KEY_REUSED,
        message:
          'Idempotency-Key must match referenceId for balance adjustments',
      });
    }
  }
}
