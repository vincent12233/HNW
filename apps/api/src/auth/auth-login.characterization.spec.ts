import {
  HttpException,
  INestApplication,
  UnauthorizedException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';
import request from 'supertest';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { createCharacterizationHttpApp } from '../testing/create-http-app';

describe('Current client login, refresh, and logout behavior', () => {
  describe('HTTP contract', () => {
    let app: INestApplication;
    const authService = {
      login: jest.fn(),
      refresh: jest.fn(),
      revokeAccessToken: jest.fn(),
    };

    beforeAll(async () => {
      const module = await Test.createTestingModule({
        controllers: [AuthController],
        providers: [{ provide: AuthService, useValue: authService }],
      }).compile();
      app = await createCharacterizationHttpApp(module);
    });

    beforeEach(() => {
      authService.login.mockReset();
      authService.refresh.mockReset();
      authService.revokeAccessToken.mockReset();
    });
    afterAll(async () => app.close());

    it('returns bearer tokens for phone-and-password login without setting a staff cookie', async () => {
      authService.login.mockResolvedValue({
        message: 'Login successful',
        accessToken: 'access',
        refreshToken: 'refresh',
        tokenType: 'Bearer',
        expiresIn: 86400,
        user: {
          id: 'u1',
          role: 'CLIENT',
          status: 'ACTIVE',
          phone: '9876543210',
        },
        account: { id: 'a1' },
      });
      const response = await request(app.getHttpServer())
        .post('/auth/login')
        .send({ phone: '9876543210', password: 'password1' })
        .expect(201);
      expect(response.body.accessToken).toBe('access');
      expect(response.body.refreshToken).toBe('refresh');
      expect(response.headers['set-cookie']).toBeUndefined();
      expect(JSON.stringify(response.body)).not.toMatch(/passwordHash/);
    });

    it('rejects a login body that includes an SMS OTP field', async () => {
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await request(app.getHttpServer())
          .post('/auth/login')
          .send({
            phone: '9876543210',
            password: 'password1',
            smsOtp: '123456',
          })
          .expect(400);
        expect(authService.login).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
      }
    });

    it('forwards authenticator or recovery verificationCode, not a separate SMS OTP', async () => {
      authService.login.mockResolvedValue({
        message: 'Login successful',
        accessToken: 'access',
        user: { id: 'u1', role: 'CLIENT', status: 'ACTIVE' },
      });
      await request(app.getHttpServer())
        .post('/auth/login')
        .send({
          phone: '9876543210',
          password: 'password1',
          verificationCode: '123456',
        })
        .expect(201);
      expect(authService.login).toHaveBeenCalledWith(
        expect.objectContaining({ verificationCode: '123456' }),
        expect.any(Object),
      );
    });

    it('surfaces twoFactorRequired from the current UnauthorizedException payload', async () => {
      authService.login.mockRejectedValue(
        new UnauthorizedException({
          message: 'Enter your authenticator code or recovery code',
          twoFactorRequired: true,
        }),
      );
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const response = await request(app.getHttpServer())
          .post('/auth/login')
          .send({ phone: '9876543210', password: 'password1' })
          .expect(401);
        expect(response.body.twoFactorRequired).toBe(true);
        expect(response.body.message).toMatch(/authenticator code or recovery code/);
      } finally {
        logging.mockRestore();
      }
    });

    it('refreshes with the current refreshToken body field', async () => {
      authService.refresh.mockResolvedValue({
        message: 'Token refreshed',
        accessToken: 'a2',
        refreshToken: 'r2',
      });
      await request(app.getHttpServer())
        .post('/auth/refresh')
        .send({ refreshToken: 'r1' })
        .expect(201)
        .expect(({ body }) => {
          expect(body.accessToken).toBe('a2');
        });
      expect(authService.refresh).toHaveBeenCalledWith('r1');
    });

    it('revokes the bearer access token on logout', async () => {
      authService.revokeAccessToken.mockResolvedValue({ loggedOut: true });
      await request(app.getHttpServer())
        .post('/auth/logout')
        .set('Authorization', 'Bearer access-token')
        .expect(201)
        .expect(({ body }) => {
          expect(body.loggedOut).toBe(true);
        });
      expect(authService.revokeAccessToken).toHaveBeenCalledWith('access-token');
    });
  });

  describe('AuthService login outcomes', () => {
    async function createService(user: Record<string, unknown> | null) {
      const passwordHash = await bcrypt.hash('password1', 4);
      const resolvedUser = user
        ? { passwordHash, phone: '9876543210', ...user }
        : null;
      const usersService = {
        findByPhone: jest.fn().mockResolvedValue(resolvedUser),
        findByEmployeeNo: jest.fn().mockResolvedValue(null),
      };
      const jwtService = {
        signAsync: jest.fn().mockResolvedValue('jwt'),
        verifyAsync: jest.fn(),
      };
      const prisma = {
        loginAudit: {
          count: jest.fn().mockResolvedValue(0),
          create: jest.fn(),
        },
        userDevice: { create: jest.fn() },
        user: { findUnique: jest.fn(), update: jest.fn() },
        $queryRaw: jest.fn(),
      };
      const twoFactor = {
        verifyLogin: jest.fn().mockResolvedValue(undefined),
        status: jest.fn().mockResolvedValue({ enabled: false }),
      };
      const service = new AuthService(
        usersService as never,
        jwtService as never,
        prisma as never,
        {} as never,
        twoFactor as never,
      );
      return { service, usersService, jwtService, prisma, twoFactor };
    }

    it('issues session tokens for an active client with the correct password', async () => {
      const { service, jwtService, prisma, twoFactor } = await createService({
        id: 'u1',
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
        authVersion: 1,
        fullName: 'Client',
        account: { id: 'a1' },
      });
      const result = await service.login({
        phone: '9876543210',
        password: 'password1',
      });
      expect(twoFactor.verifyLogin).toHaveBeenCalledWith('u1', undefined);
      expect(jwtService.signAsync).toHaveBeenCalled();
      expect(result.accessToken).toBe('jwt');
      expect(result.refreshToken).toBe('jwt');
      expect(result.user).toMatchObject({
        id: 'u1',
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
      });
      expect(JSON.stringify(result)).not.toMatch(/passwordHash/);
      expect(prisma.loginAudit.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ success: true }),
        }),
      );
    });

    it('uses the same invalid-credentials message for a missing user and a wrong password', async () => {
      const missing = await createService(null);
      await expect(
        missing.service.login({ phone: '9876543210', password: 'password1' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);

      const wrong = await createService({
        id: 'u1',
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
        authVersion: 1,
        fullName: 'Client',
        account: { id: 'a1' },
      });
      await expect(
        wrong.service.login({ phone: '9876543210', password: 'other-pass' }),
      ).rejects.toMatchObject({ message: 'Invalid account or password' });
      expect(wrong.jwtService.signAsync).not.toHaveBeenCalled();
      expect(wrong.prisma.loginAudit.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ success: false }),
        }),
      );
    });

    it('returns a KYC onboarding token for a suspended client without an approved submission', async () => {
      const { service, prisma, jwtService } = await createService({
        id: 'u1',
        role: UserRole.CLIENT,
        status: UserStatus.SUSPENDED,
        authVersion: 3,
        fullName: 'Client',
        account: { id: 'a1' },
      });
      prisma.$queryRaw.mockResolvedValue([]);
      await expect(
        service.login({ phone: '9876543210', password: 'password1' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(jwtService.signAsync).toHaveBeenCalledWith(
        expect.objectContaining({ purpose: 'KYC_ONBOARDING', sub: 'u1' }),
        { expiresIn: '30m' },
      );
    });

    it('does not issue tokens when authenticator verification fails', async () => {
      const { service, jwtService, twoFactor, prisma } = await createService({
        id: 'u1',
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
        authVersion: 1,
        fullName: 'Client',
        account: { id: 'a1' },
      });
      twoFactor.verifyLogin.mockRejectedValue(
        new UnauthorizedException({
          message: 'Enter your authenticator code or recovery code',
          twoFactorRequired: true,
        }),
      );
      await expect(
        service.login({ phone: '9876543210', password: 'password1' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(jwtService.signAsync).not.toHaveBeenCalled();
      expect(prisma.loginAudit.create).not.toHaveBeenCalled();
    });

    it('rejects a disabled account without issuing tokens', async () => {
      const { service, jwtService } = await createService({
        id: 'u1',
        role: UserRole.CLIENT,
        status: UserStatus.DISABLED,
        authVersion: 1,
        fullName: 'Client',
        account: { id: 'a1' },
      });
      await expect(
        service.login({ phone: '9876543210', password: 'password1' }),
      ).rejects.toMatchObject({ message: 'User account is not active' });
      expect(jwtService.signAsync).not.toHaveBeenCalled();
    });

    it('keeps the password-reset HTTP methods as support-contact stubs', async () => {
      const { service } = await createService(null);
      expect(() => service.requestPasswordReset('9876543210')).toThrow(
        HttpException,
      );
      expect(() =>
        service.confirmPasswordReset('9876543210', '123456', 'password1'),
      ).toThrow(/customer support session/);
    });
  });
});
