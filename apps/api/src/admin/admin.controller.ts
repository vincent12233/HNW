import { Controller, Get, Param, UseGuards } from '@nestjs/common';

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
  customers() {
    return this.adminService.customers();
  }

  @Get('customers/:customerId/login')
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  customerLastLogin(@Param('customerId') customerId: string) {
    return this.adminService.customerLastLogin(customerId);
  }

  @Get('customers/:customerId/login-audits')
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  customerLoginAudits(@Param('customerId') customerId: string) {
    return this.adminService.customerLoginAudits(customerId);
  }

  @Get('customers/:customerId/login-risk')
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  customerLoginRisk(@Param('customerId') customerId: string) {
    return this.adminService.customerLoginRisk(customerId);
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
}
