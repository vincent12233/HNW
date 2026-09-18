import {
  BadRequestException,
  ConflictException,
  INestApplication,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import {
  InviteCodeStatus,
  UserRole,
  UserStatus,
} from '../generated/prisma/enums';
import { createCharacterizationHttpApp } from '../testing/create-http-app';

const validRegister = {
  phone: '9876543210',
  password: 'password1',
  inviteCode: 'INVITE99',
};

describe('Current client registration behavior', () => {
  describe('HTTP contract', () => {
    let app: INestApplication;
    const authService = {
      register: jest.fn(),
    };

    beforeAll(async () => {
      const module = await Test.createTestingModule({
        controllers: [AuthController],
        providers: [{ provide: AuthService, useValue: authService }],
      }).compile();
      app = await createCharacterizationHttpApp(module);
    });

    beforeEach(() => authService.register.mockReset());
    afterAll(async () => app.close());

    it('accepts phone, password, and invite code without an OTP field', async () => {
      authService.register.mockResolvedValue({
        message: 'Registration successful',
        kycToken: 'kyc.jwt',
        user: {
          id: 'u1',
          fullName: 'Client 3210',
          phone: '9876543210',
          role: 'CLIENT',
          status: 'SUSPENDED',
        },
      });
      const response = await request(app.getHttpServer())
        .post('/auth/register')
        .send(validRegister)
        .expect(201);
      expect(authService.register).toHaveBeenCalledWith(validRegister);
      expect(response.body.kycToken).toBe('kyc.jwt');
      expect(response.body.user.status).toBe('SUSPENDED');
      expect(JSON.stringify(response.body)).not.toMatch(/password/i);
      expect(response.body).not.toHaveProperty('otp');
    });

    it('rejects an OTP field on the current register contract', async () => {
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const response = await request(app.getHttpServer())
          .post('/auth/register')
          .send({ ...validRegister, otp: '123456' })
          .expect(400);
        expect(authService.register).not.toHaveBeenCalled();
        expect(String(response.body.message)).toMatch(/otp/i);
      } finally {
        logging.mockRestore();
      }
    });

    it('rejects a missing invite code', async () => {
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const { inviteCode: _invite, ...body } = validRegister;
        await request(app.getHttpServer())
          .post('/auth/register')
          .send(body)
          .expect(400);
        expect(authService.register).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
      }
    });

    it('rejects a password shorter than the current 8-character minimum', async () => {
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await request(app.getHttpServer())
          .post('/auth/register')
          .send({ ...validRegister, password: 'short' })
          .expect(400);
        expect(authService.register).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
      }
    });

    it('rejects a phone number that is not an Indian mobile form', async () => {
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await request(app.getHttpServer())
          .post('/auth/register')
          .send({ ...validRegister, phone: '12345' })
          .expect(400);
        expect(authService.register).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
      }
    });
  });

  describe('AuthService register outcome', () => {
    function createService() {
      const usersService = { findByPhone: jest.fn() };
      const jwtService = {
        signAsync: jest.fn().mockResolvedValue('kyc.onboarding.jwt'),
      };
      const tx = {
        inviteCode: {
          findUnique: jest.fn(),
          updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        },
        user: { create: jest.fn() },
        $executeRaw: jest.fn().mockResolvedValue(1),
      };
      const prisma = {
        $transaction: jest.fn(async (fn: (client: typeof tx) => unknown) =>
          fn(tx),
        ),
      };
      const service = new AuthService(
        usersService as never,
        jwtService as never,
        prisma as never,
        {} as never,
        { verifyLogin: jest.fn(), status: jest.fn() } as never,
      );
      return { service, usersService, jwtService, tx, prisma };
    }

    it('creates a SUSPENDED client, synthetic phone email, and KYC onboarding token', async () => {
      const { service, usersService, jwtService, tx } = createService();
      usersService.findByPhone.mockResolvedValue(null);
      tx.inviteCode.findUnique.mockResolvedValue({
        id: 'invite-1',
        status: InviteCodeStatus.UNUSED,
        expiresAt: null,
        businessProfile: { userId: 'biz-1', isActive: true },
      });
      tx.user.create.mockResolvedValue({
        id: 'user-1',
        fullName: 'Client 3210',
        phone: '9876543210',
        role: UserRole.CLIENT,
        status: UserStatus.SUSPENDED,
        authVersion: 0,
        createdAt: new Date('2026-01-01T00:00:00.000Z'),
        passwordHash: 'should-not-leak',
      });

      const result = await service.register(validRegister);

      expect(tx.user.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            email: '919876543210@phone.hnw.local',
            phone: '9876543210',
            role: UserRole.CLIENT,
            status: UserStatus.SUSPENDED,
            assignedBusinessId: 'biz-1',
            account: {
              create: expect.objectContaining({
                currency: 'INR',
                cashBalance: 0,
                buyingPower: 0,
              }),
            },
          }),
        }),
      );
      expect(tx.user.create.mock.calls[0][0].data.account.create.accountNumber).toMatch(
        /^HNW[0-9A-F]+$/,
      );
      expect(jwtService.signAsync).toHaveBeenCalledWith(
        expect.objectContaining({
          sub: 'user-1',
          purpose: 'KYC_ONBOARDING',
          role: UserRole.CLIENT,
        }),
        { expiresIn: '30m' },
      );
      expect(result).toMatchObject({
        message: 'Registration successful',
        kycToken: 'kyc.onboarding.jwt',
        user: {
          id: 'user-1',
          phone: '9876543210',
          role: UserRole.CLIENT,
          status: UserStatus.SUSPENDED,
        },
      });
      expect(result).not.toHaveProperty('accessToken');
      expect(JSON.stringify(result)).not.toContain('should-not-leak');
      expect(JSON.stringify(result)).not.toContain(validRegister.password);
    });

    it('rejects a duplicate phone before consuming an invite code', async () => {
      const { service, usersService, tx } = createService();
      usersService.findByPhone.mockResolvedValue({ id: 'existing' });
      await expect(service.register(validRegister)).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(tx.inviteCode.findUnique).not.toHaveBeenCalled();
    });

    it('rejects an unknown invite code', async () => {
      const { service, usersService, tx } = createService();
      usersService.findByPhone.mockResolvedValue(null);
      tx.inviteCode.findUnique.mockResolvedValue(null);
      await expect(service.register(validRegister)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(tx.user.create).not.toHaveBeenCalled();
    });
  });
});
