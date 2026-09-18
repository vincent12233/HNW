import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { OtcController } from './otc.controller';
import { OtcService } from './otc.service';

describe('Current OTC HTTP role boundary', () => {
  const otc = {
    listOffers: jest.fn(),
    submit: jest.fn(),
    myOrders: jest.fn(),
    pendingOrders: jest.fn(),
    approve: jest.fn(),
    reject: jest.fn(),
  };
  const prisma = { user: { findUnique: jest.fn() } };

  async function build(role: UserRole) {
    const module = await Test.createTestingModule({
      controllers: [OtcController],
      providers: [
        { provide: OtcService, useValue: otc },
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

  it('lets CLIENT submit an OTC order with the current 4-digit transaction key', async () => {
    const app: INestApplication = await build(UserRole.CLIENT);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.CLIENT,
      status: UserStatus.ACTIVE,
    });
    otc.submit.mockResolvedValue({ id: 'otc-1', status: 'PENDING' });
    await request(app.getHttpServer())
      .post('/otc/orders')
      .send({ offerId: 'offer-1', quantity: 1, transactionKey: '1234' })
      .expect(201);
    expect(otc.submit).toHaveBeenCalledWith('client-1', 'offer-1', 1, '1234');
    await app.close();
  });

  it('forbids FINANCE from the current OTC approve path', async () => {
    const app: INestApplication = await build(UserRole.FINANCE);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.FINANCE,
      status: UserStatus.ACTIVE,
    });
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await request(app.getHttpServer())
        .patch('/otc/orders/otc-1/approve')
        .expect(403);
      expect(otc.approve).not.toHaveBeenCalled();
    } finally {
      logging.mockRestore();
      await app.close();
    }
  });
});
