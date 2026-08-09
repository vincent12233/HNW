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
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { ListAdminOrdersQueryDto } from '../orders/dto/list-admin-orders-query.dto';
import { ListAdminTradesQueryDto } from '../orders/dto/list-admin-trades-query.dto';

import { BusinessService } from './business.service';

@Controller('business')
@UseGuards(JwtAuthGuard, RolesGuard)
export class BusinessController {
  constructor(private readonly businessService: BusinessService) {}

  @Get()
  @Roles(UserRole.ADMIN)
  listBusinesses() {
    return this.businessService.listBusinesses();
  }

  @Get(':businessUserId/customers')
  @Roles(UserRole.ADMIN)
  customersByBusiness(@Param('businessUserId') businessUserId: string) {
    return this.businessService.customersByBusiness(businessUserId);
  }

  @Patch(':businessUserId/status')
  @Roles(UserRole.ADMIN)
  setBusinessStatus(
    @Param('businessUserId') businessUserId: string,
    @Body() body: { isActive: boolean },
  ) {
    return this.businessService.setBusinessActive(
      businessUserId,
      Boolean(body.isActive),
    );
  }

  @Patch(':businessUserId/reset-password')
  @Roles(UserRole.ADMIN)
  resetBusinessPassword(
    @Param('businessUserId') businessUserId: string,
    @Body() body: { newPassword?: string; password?: string },
  ) {
    return this.businessService.resetBusinessPassword(
      businessUserId,
      body.newPassword || body.password || '',
    );
  }

  // ===============================
  // 创建业务员
  // ===============================

  @Post()
  @Roles(UserRole.ADMIN)
  createBusiness(
    @Body()
    body: {
      password: string;
      fullName: string;
      phone?: string;
      employeeNo: string;
      department?: string;
    },
  ) {
    return this.businessService.createBusiness(body);
  }

  // ===============================
  // 业务员首页风险统计
  // ===============================

  @Get('my-risk-dashboard')
  @Roles(UserRole.BUSINESS)
  async myRiskDashboard(
    @Req()
    req: any,
  ) {
    return this.businessService.myRiskDashboard(req.user.userId);
  }

  // ===============================
  // 业务员充值记录
  // ===============================

  @Get('my-deposits')
  @Roles(UserRole.BUSINESS)
  myDeposits(
    @Req()
    req: any,
  ) {
    return this.businessService.myDeposits(req.user.userId);
  }

  // ===============================
  // 业务员提现记录
  // ===============================

  @Get('my-withdrawals')
  @Roles(UserRole.BUSINESS)
  myWithdrawals(
    @Req()
    req: any,
  ) {
    return this.businessService.myWithdrawals(req.user.userId);
  }

  @Get('my-orders')
  @Roles(UserRole.BUSINESS)
  myOrders(
    @Req()
    req: any,

    @Query()
    query: ListAdminOrdersQueryDto,
  ) {
    return this.businessService.myOrders(req.user.userId, query);
  }

  @Get('my-trades')
  @Roles(UserRole.BUSINESS)
  myTrades(
    @Req()
    req: any,

    @Query()
    query: ListAdminTradesQueryDto,
  ) {
    return this.businessService.myTrades(req.user.userId, query);
  }

  // ===============================
  // 我的客户
  // ===============================

  @Get('my-customers')
  @Roles(UserRole.BUSINESS)
  myCustomers(
    @Req()
    req: any,
  ) {
    return this.businessService.myCustomers(req.user.userId);
  }

  // ===============================
  // 我的业务首页
  // ===============================

  @Get('my-dashboard')
  @Roles(UserRole.BUSINESS)
  myDashboard(
    @Req()
    req: any,
  ) {
    return this.businessService.myDashboard(req.user.userId);
  }

  // ===============================
  // 客户登录记录
  // ===============================

  @Get('customers/:customerId/login')
  @Roles(UserRole.BUSINESS)
  customerLastLogin(
    @Req()
    req: any,

    @Param('customerId')
    customerId: string,
  ) {
    return this.businessService.customerLastLogin(req.user.userId, customerId);
  }

  @Get('customers/:customerId/login-audits')
  @Roles(UserRole.BUSINESS)
  customerLoginAudits(
    @Req()
    req: any,

    @Param('customerId')
    customerId: string,
  ) {
    return this.businessService.customerLoginAudits(
      req.user.userId,
      customerId,
    );
  }

  @Get('customers/:customerId/login-risk')
  @Roles(UserRole.BUSINESS)
  customerLoginRisk(
    @Req()
    req: any,

    @Param('customerId')
    customerId: string,
  ) {
    return this.businessService.customerLoginRisk(req.user.userId, customerId);
  }

  @Patch('customers/:customerId/status')
  @Roles(UserRole.BUSINESS)
  updateMyCustomerStatus(
    @Req()
    req: any,

    @Param('customerId')
    customerId: string,

    @Body()
    body: { status: UserStatus },
  ) {
    return this.businessService.updateMyCustomerStatus(
      req.user.userId,
      customerId,
      body.status,
    );
  }

  // ===============================
  // 共享风险
  // ===============================

  @Get('shared-ip-risks')
  @Roles(UserRole.BUSINESS)
  sharedIpRisks(
    @Req()
    req: any,
  ) {
    return this.businessService.sharedIpRisks(req.user.userId);
  }

  @Get('shared-device-risks')
  @Roles(UserRole.BUSINESS)
  sharedDeviceRisks(
    @Req()
    req: any,
  ) {
    return this.businessService.sharedDeviceRisks(req.user.userId);
  }

  // ===============================
  // 邀请码
  // ===============================

  @Get('invite-codes')
  @Roles(UserRole.ADMIN, UserRole.FINANCE, UserRole.BUSINESS)
  listInviteCodes(
    @Req()
    req: any,

    @Query('businessUserId')
    businessUserId?: string,
  ) {
    return this.businessService.listInviteCodes(
      req.user.userId,
      req.user.role,
      businessUserId,
    );
  }

  @Post(':businessUserId/invite-codes')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS)
  generateInviteCodes(
    @Req()
    req: any,

    @Param('businessUserId')
    businessUserId: string,

    @Body()
    body: {
      count?: number;
      expiresAt?: string;
    },
  ) {
    const targetBusinessUserId =
      req.user.role === UserRole.BUSINESS ? req.user.userId : businessUserId;

    return this.businessService.generateInviteCodes(
      targetBusinessUserId,
      Number(body.count ?? 1),
      body.expiresAt ? new Date(body.expiresAt) : undefined,
    );
  }

  @Patch('invite-codes/:codeId/disable')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS)
  disableInviteCode(
    @Req()
    req: any,

    @Param('codeId')
    codeId: string,
  ) {
    return this.businessService.disableInviteCode(
      codeId,
      req.user.userId,
      req.user.role,
    );
  }
}
