import { INestApplication, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { OrdersController } from './orders.controller';
import { TradingOrdersService } from './trading-orders.service';
import { OrdersService } from './orders.service';

const validOrder = {
  clientOrderId: 'client-order-1',
  exchange: 'NSE',
  symbol: 'TCS',
  side: 'BUY',
  type: 'MARKET',
  timeInForce: 'DAY',
  quantity: 1,
};

describe('Current client order HTTP and ownership behavior', () => {
  describe('HTTP authorization and validation', () => {
    let app: INestApplication;
    const tradingOrders = {
      createOrder: jest.fn(),
      listOrders: jest.fn(),
      getOrder: jest.fn(),
      cancelOrder: jest.fn(),
      listPositions: jest.fn(),
      getPosition: jest.fn(),
      listTrades: jest.fn(),
    };
    const prisma = { user: { findUnique: jest.fn() } };

    async function build(role: UserRole | null) {
      const builder = Test.createTestingModule({
        controllers: [OrdersController],
        providers: [
          { provide: TradingOrdersService, useValue: tradingOrders },
          { provide: PrismaService, useValue: prisma },
          RolesGuard,
        ],
      });
      builder.overrideGuard(JwtAuthGuard).useValue(
        role
          ? stubAuthenticatedUser({ userId: `${role.toLowerCase()}-1`, role })
          : {
              canActivate() {
                throw new UnauthorizedException();
              },
            },
      );
      return createCharacterizationHttpApp(await builder.compile());
    }

    afterEach(async () => {
      jest.resetAllMocks();
      if (app) await app.close();
    });

    it('rejects unauthenticated order submission', async () => {
      app = await build(null);
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await request(app.getHttpServer())
          .post('/orders')
          .send(validOrder)
          .expect(401);
        expect(tradingOrders.createOrder).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
      }
    });

    it.each([
      UserRole.ADMIN,
      UserRole.MANAGER,
      UserRole.BUSINESS,
      UserRole.FINANCE,
      UserRole.SUPPORT,
    ])('forbids %s from POST /orders', async (role) => {
      app = await build(role);
      prisma.user.findUnique.mockResolvedValue({
        role,
        status: UserStatus.ACTIVE,
      });
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await request(app.getHttpServer())
          .post('/orders')
          .send(validOrder)
          .expect(403);
        expect(tradingOrders.createOrder).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
      }
    });

    it('lets an active CLIENT submit the current MARKET/BUY payload', async () => {
      app = await build(UserRole.CLIENT);
      prisma.user.findUnique.mockResolvedValue({
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
      });
      tradingOrders.createOrder.mockResolvedValue({
        id: 'o1',
        status: 'FILLED',
        clientOrderId: validOrder.clientOrderId,
      });
      await request(app.getHttpServer())
        .post('/orders')
        .send(validOrder)
        .expect(201);
      expect(tradingOrders.createOrder).toHaveBeenCalledWith(
        'client-1',
        expect.objectContaining({
          side: 'BUY',
          type: 'MARKET',
          timeInForce: 'DAY',
          quantity: 1,
          clientOrderId: 'client-order-1',
        }),
      );
    });

    it('accepts a matching Idempotency-Key and forwards the client order id', async () => {
      app = await build(UserRole.CLIENT);
      prisma.user.findUnique.mockResolvedValue({
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
      });
      tradingOrders.createOrder.mockResolvedValue({ id: 'o-idem', status: 'FILLED' });
      await request(app.getHttpServer())
        .post('/orders')
        .set('Idempotency-Key', validOrder.clientOrderId)
        .send(validOrder)
        .expect(201);
      expect(tradingOrders.createOrder).toHaveBeenCalledWith(
        'client-1',
        expect.objectContaining({ clientOrderId: validOrder.clientOrderId }),
      );
    });

    it('rejects a mismatched Idempotency-Key before submission', async () => {
      app = await build(UserRole.CLIENT);
      prisma.user.findUnique.mockResolvedValue({
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
      });
      await request(app.getHttpServer())
        .post('/orders')
        .set('Idempotency-Key', 'different-order-key')
        .send(validOrder)
        .expect(400);
      expect(tradingOrders.createOrder).not.toHaveBeenCalled();
    });

    it('rejects an unsupported GTT order type on the current DTO', async () => {
      app = await build(UserRole.CLIENT);
      prisma.user.findUnique.mockResolvedValue({
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
      });
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await request(app.getHttpServer())
          .post('/orders')
          .send({ ...validOrder, type: 'GTT' })
          .expect(400);
        expect(tradingOrders.createOrder).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
      }
    });

    it('accepts the current LIMIT, SELL, and FOK fields', async () => {
      app = await build(UserRole.CLIENT);
      prisma.user.findUnique.mockResolvedValue({
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
      });
      tradingOrders.createOrder.mockResolvedValue({ id: 'o2', status: 'OPEN' });
      await request(app.getHttpServer())
        .post('/orders')
        .send({
          ...validOrder,
          clientOrderId: 'client-order-2',
          side: 'SELL',
          type: 'LIMIT',
          timeInForce: 'FOK',
          limitPrice: '100.50',
        })
        .expect(201);
      expect(tradingOrders.createOrder).toHaveBeenCalledWith(
        'client-1',
        expect.objectContaining({
          side: 'SELL',
          type: 'LIMIT',
          timeInForce: 'FOK',
          limitPrice: '100.50',
        }),
      );
    });

    it('lets CLIENT cancel through the current ownership-scoped cancel path', async () => {
      app = await build(UserRole.CLIENT);
      prisma.user.findUnique.mockResolvedValue({
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
      });
      tradingOrders.cancelOrder.mockResolvedValue({
        id: 'o1',
        status: 'CANCELLED',
      });
      await request(app.getHttpServer()).post('/orders/o1/cancel').expect(201);
      expect(tradingOrders.cancelOrder).toHaveBeenCalledWith('client-1', 'o1');
    });
  });

  describe('OrdersService ownership', () => {
    it('looks up orders only on the caller account and hides other users as not found', async () => {
      const prisma = {
        order: { findFirst: jest.fn().mockResolvedValue(null) },
      };
      const service = new OrdersService(prisma as never);
      await expect(service.getOrder('user-a', 'order-b')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.order.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'order-b', account: { userId: 'user-a' } },
        }),
      );
    });
  });
});
