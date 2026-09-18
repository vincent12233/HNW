import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { ClientIpoController } from './client-ipo.controller';
import { IpoService } from './ipo.service';

describe('Current client IPO HTTP role boundary', () => {
  const ipoService = {
    listOpenIpos: jest.fn(),
    apply: jest.fn(),
    listMyDebts: jest.fn(),
    listMyApplications: jest.fn(),
    getApplicationLimit: jest.fn(),
  };
  const prisma = { user: { findUnique: jest.fn() } };

  async function build(role: UserRole) {
    const module = await Test.createTestingModule({
      controllers: [ClientIpoController],
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

  it('lets CLIENT list open IPOs and forbids ADMIN from applying', async () => {
    const clientApp: INestApplication = await build(UserRole.CLIENT);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.CLIENT,
      status: UserStatus.ACTIVE,
    });
    ipoService.listOpenIpos.mockResolvedValue([]);
    await request(clientApp.getHttpServer()).get('/ipo/open').expect(200);
    await clientApp.close();

    const adminApp = await build(UserRole.ADMIN);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.ADMIN,
      status: UserStatus.ACTIVE,
    });
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await request(adminApp.getHttpServer()).post('/ipo/ipo-1/apply').expect(403);
      expect(ipoService.apply).not.toHaveBeenCalled();
    } finally {
      logging.mockRestore();
      await adminApp.close();
    }
  });

  it('lets CLIENT read current IPO debts on /ipo/debts/me', async () => {
    const app: INestApplication = await build(UserRole.CLIENT);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.CLIENT,
      status: UserStatus.ACTIVE,
    });
    ipoService.listMyDebts.mockResolvedValue([]);
    await request(app.getHttpServer()).get('/ipo/debts/me').expect(200);
    expect(ipoService.listMyDebts).toHaveBeenCalledWith('client-1');
    await app.close();
  });
});
