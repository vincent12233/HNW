import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { WithdrawalController } from './withdrawal.controller';
import { WithdrawalService } from './withdrawal.service';

describe('Current withdrawal HTTP role boundaries', () => {
  const withdrawals = {
    createRequest: jest.fn(),
    myWithdrawals: jest.fn(),
    listPendingWithdrawals: jest.fn(),
    approveWithdrawal: jest.fn(),
    rejectWithdrawal: jest.fn(),
  };
  const prisma = { user: { findUnique: jest.fn() } };

  async function build(role: UserRole) {
    const module = await Test.createTestingModule({
      controllers: [WithdrawalController],
      providers: [
        { provide: WithdrawalService, useValue: withdrawals },
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

  it('lets CLIENT create a withdrawal request and forbids BUSINESS from approving', async () => {
    const clientApp = await build(UserRole.CLIENT);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.CLIENT,
      status: UserStatus.ACTIVE,
    });
    withdrawals.createRequest.mockResolvedValue({ id: 'w1' });
    await request(clientApp.getHttpServer())
      .post('/withdrawal/request')
      .send({
        amount: '10.00',
        bankName: 'HDFC',
        accountNumber: '123456789',
        ifscCode: 'HDFC0000001',
        withdrawalPin: '123456',
      })
      .expect(201);
    await clientApp.close();

    const businessApp = await build(UserRole.BUSINESS);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.BUSINESS,
      status: UserStatus.ACTIVE,
    });
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await request(businessApp.getHttpServer())
        .patch('/withdrawal/w1/approve')
        .expect(403);
      expect(withdrawals.approveWithdrawal).not.toHaveBeenCalled();
    } finally {
      logging.mockRestore();
      await businessApp.close();
    }
  });

  it('lets FINANCE approve the current withdrawal review endpoint', async () => {
    const app: INestApplication = await build(UserRole.FINANCE);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.FINANCE,
      status: UserStatus.ACTIVE,
    });
    withdrawals.approveWithdrawal.mockResolvedValue({ id: 'w1', status: 'APPROVED' });
    await request(app.getHttpServer()).patch('/withdrawal/w1/approve').expect(200);
    expect(withdrawals.approveWithdrawal).toHaveBeenCalledWith(
      'w1',
      'finance-1',
      UserRole.FINANCE,
    );
    await app.close();
  });
});
