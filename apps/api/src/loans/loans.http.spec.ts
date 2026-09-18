import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { LoansController } from './loans.controller';
import { LoansService } from './loans.service';

describe('Current loan HTTP role boundary', () => {
  const loans = {
    clientLoans: jest.fn(),
    apply: jest.fn(),
    list: jest.fn(),
    create: jest.fn(),
    approve: jest.fn(),
    reject: jest.fn(),
    disburse: jest.fn(),
    repay: jest.fn(),
    markOverdue: jest.fn(),
  };
  const prisma = { user: { findUnique: jest.fn() } };

  async function build(role: UserRole) {
    const module = await Test.createTestingModule({
      controllers: [LoansController],
      providers: [
        { provide: LoansService, useValue: loans },
        { provide: PrismaService, useValue: prisma },
        RolesGuard,
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(
        stubAuthenticatedUser({ userId: `${role.toLowerCase()}-1`, role }),
      )
      .compile();
    return createCharacterizationHttpApp(await module);
  }

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('lets CLIENT apply and forbids BUSINESS from the current finance approve path', async () => {
    const clientApp: INestApplication = await build(UserRole.CLIENT);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.CLIENT,
      status: UserStatus.ACTIVE,
    });
    loans.apply.mockResolvedValue({ id: 'loan-1', status: 'APPLIED' });
    await request(clientApp.getHttpServer()).post('/loans/apply').expect(201);
    expect(loans.apply).toHaveBeenCalledWith('client-1');
    await clientApp.close();

    const businessApp = await build(UserRole.BUSINESS);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.BUSINESS,
      status: UserStatus.ACTIVE,
    });
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await request(businessApp.getHttpServer())
        .patch('/loans/loan-1/approve')
        .send({ note: 'ok' })
        .expect(403);
      expect(loans.approve).not.toHaveBeenCalled();
    } finally {
      logging.mockRestore();
      await businessApp.close();
    }
  });

  it('lets FINANCE approve on the current loan review endpoint', async () => {
    const app: INestApplication = await build(UserRole.FINANCE);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.FINANCE,
      status: UserStatus.ACTIVE,
    });
    loans.approve.mockResolvedValue({ id: 'loan-1', status: 'APPROVED' });
    await request(app.getHttpServer())
      .patch('/loans/loan-1/approve')
      .send({ approvedAmount: '1000.00' })
      .expect(200);
    expect(loans.approve).toHaveBeenCalledWith(
      'loan-1',
      'finance-1',
      UserRole.FINANCE,
      expect.objectContaining({ approvedAmount: '1000.00' }),
    );
    await app.close();
  });
});
