import { Test } from '@nestjs/testing';
import request from 'supertest';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { DedicatedOperatorScopeGuard } from './dedicated-operator-scope.guard';
import { BusinessController } from './business.controller';
import { BusinessService } from './business.service';
import { TeamService } from './team.service';

describe('Business dashboard HTTP role boundaries', () => {
  const businessId = 'business-dashboard-http-test';
  const dashboard = {
    totalCustomers: 0,
    totalAssets: '0.00',
    pendingDeposits: 0,
  };
  const riskDashboard = {
    sharedIpCustomers: 0,
    sharedDeviceCustomers: 0,
    failedLogin24h: 0,
    highRiskCustomers: 0,
  };
  const business = {
    myDashboard: jest.fn(),
    myRiskDashboard: jest.fn(),
  };
  const team = {};
  const prisma = {
    user: {
      findUnique: jest.fn(),
      findFirst: jest.fn(),
    },
  };

  async function buildApp(role: UserRole) {
    prisma.user.findUnique.mockResolvedValue({
      role,
      status: UserStatus.ACTIVE,
    });
    const module = await Test.createTestingModule({
      controllers: [BusinessController],
      providers: [
        { provide: BusinessService, useValue: business },
        { provide: TeamService, useValue: team },
        { provide: PrismaService, useValue: prisma },
        RolesGuard,
        DedicatedOperatorScopeGuard,
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(stubAuthenticatedUser({ userId: businessId, role }))
      .compile();

    return createCharacterizationHttpApp(module);
  }

  beforeEach(() => {
    business.myDashboard.mockResolvedValue(dashboard);
    business.myRiskDashboard.mockResolvedValue(riskDashboard);
  });

  afterEach(() => jest.resetAllMocks());

  it('passes authenticated BUSINESS identity and response shapes through both read routes', async () => {
    const app = await buildApp(UserRole.BUSINESS);
    try {
      await request(app.getHttpServer())
        .get('/business/my-dashboard')
        .expect(200, dashboard);
      await request(app.getHttpServer())
        .get('/business/my-risk-dashboard')
        .expect(200, riskDashboard);

      expect(business.myDashboard).toHaveBeenCalledWith(businessId);
      expect(business.myRiskDashboard).toHaveBeenCalledWith(businessId);
    } finally {
      await app.close();
    }
  });

  it('continues to forbid CLIENT identities from dashboard reads', async () => {
    const app = await buildApp(UserRole.CLIENT);
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await request(app.getHttpServer()).get('/business/my-dashboard').expect(403);
      await request(app.getHttpServer())
        .get('/business/my-risk-dashboard')
        .expect(403);

      expect(business.myDashboard).not.toHaveBeenCalled();
      expect(business.myRiskDashboard).not.toHaveBeenCalled();
    } finally {
      logging.mockRestore();
      await app.close();
    }
  });
});
