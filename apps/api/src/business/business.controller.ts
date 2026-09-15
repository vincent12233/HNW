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
import { AllocateIpoDto } from '../ipo/dto/allocate-ipo.dto';

import { BusinessService } from './business.service';
import { DedicatedOperatorScopeGuard } from './dedicated-operator-scope.guard';
import { TeamService } from './team.service';
import { CreateTeamStaffDto, InvitePoolDto } from './team.dto';

@Controller('business')
@UseGuards(JwtAuthGuard, RolesGuard, DedicatedOperatorScopeGuard)
export class BusinessController {
  constructor(
    private readonly businessService: BusinessService,
    private readonly team: TeamService,
  ) {}

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
  @Roles(UserRole.MANAGER)
  createBusiness(@Req() req: any, @Body() body: CreateTeamStaffDto) {
    return this.team.create(req.user.userId, body);
  }

  // ===============================
  // 业务员首页风险统计
  // ===============================

  @Get('my-risk-dashboard')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
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
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
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
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  myWithdrawals(
    @Req()
    req: any,
  ) {
    return this.businessService.myWithdrawals(req.user.userId);
  }

  @Get('my-orders')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  myOrders(
    @Req()
    req: any,

    @Query()
    query: ListAdminOrdersQueryDto,
  ) {
    return this.businessService.myOrders(req.user.userId, query);
  }

  @Get('my-ipo-applications')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  myIpoApplications(@Req() req: any) {
    return this.businessService.myIpoApplications(req.user.userId);
  }

  @Patch('my-ipo-applications/:applicationId/allocate')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  allocateMyIpoApplication(
    @Req() req: any,
    @Param('applicationId') applicationId: string,
    @Body() dto: AllocateIpoDto,
  ) {
    return this.businessService.allocateMyIpoApplication(
      req.user.userId,
      applicationId,
      dto.quantity,
      dto.price,
    );
  }

  @Get('my-trades')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  myTrades(
    @Req()
    req: any,

    @Query()
    query: ListAdminTradesQueryDto,
  ) {
    return this.businessService.myTrades(req.user.userId, query);
  }

  @Get('my-trade-pairs')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  myTradePairs(@Req() req: any, @Query('customerId') customerId?: string) {
    return this.businessService.myTradePairs(req.user.userId, customerId);
  }

  @Get('my-positions')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  myPositions(
    @Req()
    req: any,

    @Query('category')
    category?: string,

    @Query('search')
    search?: string,
  ) {
    return this.businessService.myPositions(req.user.userId, {
      category,
      search,
    });
  }

  // ===============================
  // 我的客户
  // ===============================

  @Get('my-customers')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
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
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
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
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  customerLastLogin(
    @Req()
    req: any,

    @Param('customerId')
    customerId: string,
  ) {
    return this.businessService.customerLastLogin(req.user.userId, customerId);
  }

  @Get('customers/:customerId/login-audits')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
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
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  customerLoginRisk(
    @Req()
    req: any,

    @Param('customerId')
    customerId: string,
  ) {
    return this.businessService.customerLoginRisk(req.user.userId, customerId);
  }

  @Patch('customers/:customerId/status')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
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

  @Post('my-ipo-applications/publish')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  publishMyIpoApplications(@Req() req: any, @Body() body: { ids: string[] }) {
    return this.businessService.publishMyIpoApplications(
      req.user.userId,
      body.ids,
    );
  }

  @Patch('customers/:customerId/tier')
  @Roles(UserRole.BUSINESS)
  updateCustomerTier(
    @Req() req: any,
    @Param('customerId') customerId: string,
    @Body() body: { tier: unknown },
  ) {
    return this.businessService.updateCustomerTier(
      req.user.userId,
      customerId,
      body.tier,
    );
  }

  // ===============================
  // 共享风险
  // ===============================

  @Get('shared-ip-risks')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  sharedIpRisks(
    @Req()
    req: any,
  ) {
    return this.businessService.sharedIpRisks(req.user.userId);
  }

  @Get('shared-device-risks')
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
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
  @Roles(UserRole.ADMIN, UserRole.FINANCE)
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
  @Roles(UserRole.MANAGER)
  async generateInviteCodes(
    @Req()
    req: any,

    @Param('businessUserId')
    businessUserId: string,

    @Body()
    body: InvitePoolDto,
  ) {
    await this.team.business(req.user.userId, businessUserId);
    const codes = await this.businessService.generateInviteCodes(
      businessUserId,
      body.count,
    );
    await this.team.audit(
      req.user.userId,
      businessUserId,
      'MANAGER_INVITE_POOL_GENERATED',
    );
    return { count: codes.length };
  }

  @Get('my-invite-code')
  @Roles(UserRole.BUSINESS)
  currentInvite(@Req() req: any, @Query('previousId') previousId?: string) {
    return this.businessService.currentInviteCode(req.user.userId, previousId);
  }

  @Patch('invite-codes/:codeId/disable')
  @Roles(UserRole.ADMIN)
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
