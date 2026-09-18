import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { AdminAccountController } from './admin-account.controller';
import { AdminAccountService } from './admin-account.service';

describe('Current admin credit HTTP role boundary', () => {
  const accounts = { credit: jest.fn(), debit: jest.fn(), listAccounts: jest.fn() };
  const prisma = { user: { findUnique: jest.fn() } };

  async function build(role: UserRole) {
    const module = await Test.createTestingModule({
      controllers: [AdminAccountController],
      providers: [
        { provide: AdminAccountService, useValue: accounts },
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

  it('lets FINANCE credit and forbids BUSINESS from the current credit endpoint', async () => {
    const financeApp: INestApplication = await build(UserRole.FINANCE);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.FINANCE,
      status: UserStatus.ACTIVE,
    });
    accounts.credit.mockResolvedValue({ credited: true });
    await request(financeApp.getHttpServer())
      .post('/admin/accounts/ACC1/credit')
      .send({ amount: '10.00', referenceId: 'credit-01', note: 'test' })
      .expect(201);
    await financeApp.close();

    const businessApp = await build(UserRole.BUSINESS);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.BUSINESS,
      status: UserStatus.ACTIVE,
    });
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await request(businessApp.getHttpServer())
        .post('/admin/accounts/ACC1/credit')
        .send({ amount: '10.00', referenceId: 'credit-01' })
        .expect(403);
      expect(accounts.credit).toHaveBeenCalledTimes(1);
    } finally {
      logging.mockRestore();
      await businessApp.close();
    }
  });
});
