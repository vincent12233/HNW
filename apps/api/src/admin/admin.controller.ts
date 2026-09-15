import { Controller, Get, Param, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';

import { AdminService } from './admin.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('customers')
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  customers(@Req() req: any) {
    return this.adminService.customers(req.user.role);
  }

  @Get('customers/:customerId/overview')
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  customerOverview(@Param('customerId') customerId: string, @Req() req: any) {
    return this.adminService.customerOverview(customerId, req.user.role);
  }

  @Get('customers/:customerId/login')
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  customerLastLogin(@Param('customerId') customerId: string, @Req() req: any) {
    return this.adminService.customerLastLogin(customerId, req.user.role);
  }

  @Get('customers/:customerId/login-audits')
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  customerLoginAudits(
    @Param('customerId') customerId: string,
    @Req() req: any,
  ) {
    return this.adminService.customerLoginAudits(customerId, req.user.role);
  }

  @Get('customers/:customerId/login-risk')
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  customerLoginRisk(@Param('customerId') customerId: string, @Req() req: any) {
    return this.adminService.customerLoginRisk(customerId, req.user.role);
  }

  @Get('login-risk-summary')
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  loginRiskSummary() {
    return this.adminService.loginRiskSummary();
  }

  @Get('shared-ip-risks')
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  sharedIpRisks() {
    return this.adminService.sharedIpRisks();
  }

  @Get('pending-counts')
  @Roles(
    UserRole.ADMIN,
    UserRole.MANAGER,
    UserRole.BUSINESS,
    UserRole.FINANCE,
    UserRole.SUPPORT,
  )
  pendingCounts(@Req() req: any) {
    return this.adminService.pendingCounts(req.user.role, req.user.userId);
  }
}
