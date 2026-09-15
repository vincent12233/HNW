import {
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
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { LoanStatus, UserRole } from '../generated/prisma/enums';
import { ApproveLoanDto } from './dto/approve-loan.dto';
import { CreateLoanDto } from './dto/create-loan.dto';
import { RepayLoanDto } from './dto/repay-loan.dto';
import { LoansService } from './loans.service';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('loans')
@UseGuards(JwtAuthGuard, RolesGuard)
export class LoansController {
  constructor(private readonly loansService: LoansService) {}

  @Get('mine')
  @Roles(UserRole.CLIENT)
  mine(@Req() req: AuthenticatedRequest) {
    return this.loansService.clientLoans(req.user.userId);
  }

  @Post('apply')
  @Roles(UserRole.CLIENT)
  apply(@Req() req: AuthenticatedRequest) {
    return this.loansService.apply(req.user.userId);
  }

  @Get()
  @Roles(UserRole.ADMIN, UserRole.FINANCE, UserRole.BUSINESS)
  list(
    @Req() req: AuthenticatedRequest,
    @Query('search') search?: string,
    @Query('status') status?: LoanStatus,
  ) {
    return this.loansService.list(req.user.userId, req.user.role, {
      search,
      status,
    });
  }

  @Post()
  @Roles(UserRole.FINANCE)
  create(@Req() req: AuthenticatedRequest, @Body() body: CreateLoanDto) {
    return this.loansService.create(req.user.userId, req.user.role, body);
  }

  @Patch(':id/approve')
  @Roles(UserRole.FINANCE)
  approve(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() body: ApproveLoanDto,
  ) {
    return this.loansService.approve(id, req.user.userId, req.user.role, body);
  }

  @Patch(':id/reject')
  @Roles(UserRole.FINANCE)
  reject(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() body: { note?: string },
  ) {
    return this.loansService.reject(
      id,
      req.user.userId,
      req.user.role,
      body.note,
    );
  }

  @Patch(':id/disburse')
  @Roles(UserRole.FINANCE)
  disburse(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() body: { note?: string },
  ) {
    return this.loansService.disburse(
      id,
      req.user.userId,
      req.user.role,
      body.note,
    );
  }

  @Patch(':id/repay')
  @Roles(UserRole.FINANCE)
  repay(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() body: RepayLoanDto,
  ) {
    return this.loansService.repay(
      id,
      req.user.userId,
      req.user.role,
      body.amount,
      body.note,
    );
  }

  @Patch(':id/overdue')
  @Roles(UserRole.FINANCE)
  overdue(@Param('id') id: string, @Req() req: AuthenticatedRequest) {
    return this.loansService.markOverdue(id, req.user.role);
  }
}
