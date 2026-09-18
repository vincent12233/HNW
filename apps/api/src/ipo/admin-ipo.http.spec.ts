import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { AdminIpoController } from './admin-ipo.controller';
import { IpoService } from './ipo.service';

describe('Current admin IPO debt HTTP role boundary', () => {
  const ipoService = {
    listDebts: jest.fn(),
    create: jest.fn(),
    list: jest.fn(),
  };
  const prisma = { user: { findUnique: jest.fn() } };

  async function build(role: UserRole) {
    const module = await Test.createTestingModule({
      controllers: [AdminIpoController],
      providers: [
        { provide: IpoService, useValue: ipoService },
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

  it('lets FINANCE list IPO debts and forbids CLIENT from the admin debt list', async () => {
    const financeApp: INestApplication = await build(UserRole.FINANCE);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.FINANCE,
      status: UserStatus.ACTIVE,
    });
    ipoService.listDebts.mockResolvedValue([]);
    await request(financeApp.getHttpServer()).get('/admin/ipo/debts').expect(200);
    expect(ipoService.listDebts).toHaveBeenCalledWith(
      'finance-1',
      UserRole.FINANCE,
      undefined,
    );
    await financeApp.close();

    const clientApp = await build(UserRole.CLIENT);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.CLIENT,
      status: UserStatus.ACTIVE,
    });
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await request(clientApp.getHttpServer()).get('/admin/ipo/debts').expect(403);
      expect(ipoService.listDebts).toHaveBeenCalledTimes(1);
    } finally {
      logging.mockRestore();
      await clientApp.close();
    }
  });
});
