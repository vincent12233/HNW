import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { DedicatedOperatorScopeGuard } from '../business/dedicated-operator-scope.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { DepositController } from './deposit.controller';
import { DepositService } from './deposit.service';
import { AppContentService } from '../app-content/app-content.service';

describe('Current deposit request HTTP behavior', () => {
  let app: INestApplication;
  const depositService = {
    approveDeposit: jest.fn(),
    listPendingDeposits: jest.fn(),
  };
  const appContent = {
    getDepositRejectMessage: jest
      .fn()
      .mockResolvedValue('Please contact support to deposit funds.'),
  };
  const prisma = { user: { findUnique: jest.fn(), findFirst: jest.fn() } };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [DepositController],
      providers: [
        { provide: DepositService, useValue: depositService },
        { provide: AppContentService, useValue: appContent },
        { provide: PrismaService, useValue: prisma },
        RolesGuard,
        DedicatedOperatorScopeGuard,
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(
        stubAuthenticatedUser({ userId: 'client-1', role: UserRole.CLIENT }),
      )
      .compile();
    app = await createCharacterizationHttpApp(module);
  });

  afterAll(async () => app.close());

  it('keeps client self-serve deposit requests rejected by the current support-led flow', async () => {
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.CLIENT,
      status: UserStatus.ACTIVE,
    });
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const response = await request(app.getHttpServer())
        .post('/deposit/request')
        .expect(400);
      expect(response.body.message).toMatch(/contact support to deposit funds/i);
      expect(depositService.approveDeposit).not.toHaveBeenCalled();
    } finally {
      logging.mockRestore();
    }
  });
});
