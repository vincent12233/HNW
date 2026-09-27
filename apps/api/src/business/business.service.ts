import { Injectable } from '@nestjs/common';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { ListAdminOrdersQueryDto } from '../orders/dto/list-admin-orders-query.dto';
import { ListAdminTradesQueryDto } from '../orders/dto/list-admin-trades-query.dto';
import { IpoService } from '../ipo/ipo.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { BusinessCustomerService } from './business-customer.service';
import { BusinessDashboardService } from './business-dashboard.service';
import { BusinessIpoService } from './business-ipo.service';
import {
  BusinessManagementService,
  type CreateBusinessInput,
} from './business-management.service';
import { BusinessRiskService } from './business-risk.service';
import { BusinessTradingService } from './business-trading.service';

@Injectable()
export class BusinessService {
  private readonly customerService: BusinessCustomerService;
  private readonly dashboardService: BusinessDashboardService;
  private readonly ipoOperations: BusinessIpoService;
  private readonly managementService: BusinessManagementService;
  private readonly riskService: BusinessRiskService;
  private readonly tradingService: BusinessTradingService;

  constructor(
    prisma: PrismaService,
    ipoService: IpoService,
    auditService: AuditService,
  ) {
    this.customerService = new BusinessCustomerService(prisma, auditService);
    this.dashboardService = new BusinessDashboardService(prisma);
    this.ipoOperations = new BusinessIpoService(
      prisma,
      ipoService,
      auditService,
    );
    this.managementService = new BusinessManagementService(prisma);
    this.riskService = new BusinessRiskService(prisma);
    this.tradingService = new BusinessTradingService(prisma);
  }

  myDashboard(businessUserId: string) {
    return this.dashboardService.myDashboard(businessUserId);
  }

  myDeposits(businessUserId: string) {
    return this.dashboardService.myDeposits(businessUserId);
  }

  myWithdrawals(businessUserId: string) {
    return this.dashboardService.myWithdrawals(businessUserId);
  }

  createBusiness(input: CreateBusinessInput) {
    return this.managementService.createBusiness(input);
  }

  listBusinesses() {
    return this.managementService.listBusinesses();
  }

  generateInviteCodes(businessUserId: string, count: number, expiresAt?: Date) {
    return this.managementService.generateInviteCodes(
      businessUserId,
      count,
      expiresAt,
    );
  }

  currentInviteCode(businessUserId: string, previousId?: string) {
    return this.managementService.currentInviteCode(businessUserId, previousId);
  }

  listInviteCodes(
    currentUserId: string,
    currentRole: UserRole,
    businessUserId?: string,
  ) {
    return this.managementService.listInviteCodes(
      currentUserId,
      currentRole,
      businessUserId,
    );
  }

  customersByBusiness(businessUserId: string) {
    return this.customerService.customersByBusiness(businessUserId);
  }

  setBusinessActive(businessUserId: string, isActive: boolean) {
    return this.managementService.setBusinessActive(businessUserId, isActive);
  }

  resetBusinessPassword(businessUserId: string, newPassword: string) {
    return this.managementService.resetBusinessPassword(
      businessUserId,
      newPassword,
    );
  }

  disableInviteCode(
    codeId: string,
    currentUserId: string,
    currentRole: UserRole,
  ) {
    return this.managementService.disableInviteCode(
      codeId,
      currentUserId,
      currentRole,
    );
  }

  myCustomers(businessUserId: string) {
    return this.customerService.myCustomers(businessUserId);
  }

  updateMyCustomerStatus(
    businessUserId: string,
    customerId: string,
    status: UserStatus,
  ) {
    return this.customerService.updateMyCustomerStatus(
      businessUserId,
      customerId,
      status,
    );
  }

  updateCustomerTier(
    actorId: string,
    customerId: string,
    tier: unknown,
    reason?: unknown,
  ) {
    return this.customerService.updateCustomerTier(
      actorId,
      customerId,
      tier,
      reason,
    );
  }

  myIpoApplications(businessUserId: string) {
    return this.ipoOperations.myIpoApplications(businessUserId);
  }

  allocateMyIpoApplication(
    businessUserId: string,
    applicationId: string,
    quantity: number,
    price: number | string,
  ) {
    return this.ipoOperations.allocateMyIpoApplication(
      businessUserId,
      applicationId,
      quantity,
      price,
    );
  }

  publishMyIpoApplications(businessUserId: string, ids: string[]) {
    return this.ipoOperations.publishMyIpoApplications(businessUserId, ids);
  }

  myOrders(businessUserId: string, query: ListAdminOrdersQueryDto) {
    return this.tradingService.myOrders(businessUserId, query);
  }

  myTrades(businessUserId: string, query: ListAdminTradesQueryDto) {
    return this.tradingService.myTrades(businessUserId, query);
  }

  myTradePairs(businessUserId: string, customerId?: string) {
    return this.tradingService.myTradePairs(businessUserId, customerId);
  }

  myPositions(
    businessUserId: string,
    query: { category?: string; search?: string },
  ) {
    return this.tradingService.myPositions(businessUserId, query);
  }

  customerLastLogin(businessUserId: string, customerId: string) {
    return this.riskService.customerLastLogin(businessUserId, customerId);
  }

  customerLoginAudits(businessUserId: string, customerId: string) {
    return this.riskService.customerLoginAudits(businessUserId, customerId);
  }

  customerLoginRisk(businessUserId: string, customerId: string) {
    return this.riskService.customerLoginRisk(businessUserId, customerId);
  }

  sharedIpRisks(businessUserId: string) {
    return this.riskService.sharedIpRisks(businessUserId);
  }

  myRiskDashboard(businessUserId: string) {
    return this.riskService.myRiskDashboard(businessUserId);
  }

  sharedDeviceRisks(businessUserId: string) {
    return this.riskService.sharedDeviceRisks(businessUserId);
  }
}
