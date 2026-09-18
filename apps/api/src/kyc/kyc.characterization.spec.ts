import {
  BadRequestException,
  ExecutionContext,
  INestApplication,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { DedicatedOperatorScopeGuard } from '../business/dedicated-operator-scope.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { KycController } from './kyc.controller';
import { KycAccessGuard } from './kyc-access.guard';
import { KycService } from './kyc.service';

describe('Current KYC HTTP and review behavior', () => {
  describe('Unauthenticated and role boundaries', () => {
    let app: INestApplication;
    const kycService = {
      submit: jest.fn(),
      status: jest.fn(),
      pendingForBusiness: jest.fn(),
      fileForBusiness: jest.fn(),
      review: jest.fn(),
    };
    const prisma = {
      user: { findUnique: jest.fn(), findFirst: jest.fn() },
    };
    const jwtService = {
      verifyAsync: jest.fn().mockRejectedValue(new Error('invalid token')),
    };

    async function build(role: UserRole | null) {
      const builder = Test.createTestingModule({
        controllers: [KycController],
        providers: [
          { provide: KycService, useValue: kycService },
          { provide: PrismaService, useValue: prisma },
          { provide: JwtService, useValue: jwtService },
          RolesGuard,
          DedicatedOperatorScopeGuard,
        ],
      });
      if (role) {
        builder.overrideGuard(JwtAuthGuard).useValue(
          stubAuthenticatedUser({ userId: `${role.toLowerCase()}-1`, role }),
        );
        builder.overrideGuard(KycAccessGuard).useValue(
          stubAuthenticatedUser({
            userId: `${role.toLowerCase()}-1`,
            role,
            onboarding: role === UserRole.CLIENT,
          }),
        );
      }
      const module = await builder.compile();
      return createCharacterizationHttpApp(module);
    }

    afterEach(async () => {
      if (app) await app.close();
    });

    it('rejects KYC submit without a bearer token', async () => {
      app = await build(null);
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await request(app.getHttpServer()).post('/kyc/submit').send({}).expect(401);
        expect(kycService.submit).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
      }
    });

    it('lets a client submit KYC and read status', async () => {
      app = await build(UserRole.CLIENT);
      prisma.user.findUnique.mockResolvedValue({
        role: UserRole.CLIENT,
        status: UserStatus.SUSPENDED,
      });
      kycService.submit.mockResolvedValue({ status: 'PENDING' });
      kycService.status.mockResolvedValue({ status: 'PENDING' });
      await request(app.getHttpServer())
        .post('/kyc/submit')
        .send({ documentType: 'PAN' })
        .expect(201);
      expect(kycService.submit).toHaveBeenCalledWith('client-1', {
        documentType: 'PAN',
      });
      await request(app.getHttpServer()).get('/kyc/status').expect(200);
    });

    it('forbids a client from reviewing or listing pending KYC', async () => {
      app = await build(UserRole.CLIENT);
      prisma.user.findUnique.mockResolvedValue({
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
      });
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await request(app.getHttpServer()).get('/kyc/business/pending').expect(403);
        await request(app.getHttpServer())
          .patch('/kyc/business/review')
          .send({ submissionId: 's1', decision: 'APPROVED' })
          .expect(403);
        expect(kycService.review).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
      }
    });

    it.each([UserRole.ADMIN, UserRole.FINANCE, UserRole.MANAGER])(
      'forbids %s from /kyc/business/review (BUSINESS and SUPPORT only)',
      async (role) => {
        app = await build(role);
        prisma.user.findUnique.mockResolvedValue({
          role,
          status: UserStatus.ACTIVE,
        });
        const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
        try {
          await request(app.getHttpServer())
            .patch('/kyc/business/review')
            .send({ submissionId: 's1', decision: 'APPROVED' })
            .expect(403);
          expect(kycService.review).not.toHaveBeenCalled();
        } finally {
          logging.mockRestore();
        }
      },
    );

    it('forbids CLIENT from the current KYC file endpoint', async () => {
      app = await build(UserRole.CLIENT);
      prisma.user.findUnique.mockResolvedValue({
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
      });
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await request(app.getHttpServer())
          .get('/kyc/business/s1/file')
          .query({ side: 'front' })
          .expect(403);
        expect(kycService.fileForBusiness).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
      }
    });

    it('allows BUSINESS to review assigned pending submissions', async () => {
      app = await build(UserRole.BUSINESS);
      prisma.user.findUnique.mockResolvedValue({
        role: UserRole.BUSINESS,
        status: UserStatus.ACTIVE,
      });
      kycService.review.mockResolvedValue({ reviewed: true, status: 'APPROVED' });
      await request(app.getHttpServer())
        .patch('/kyc/business/review')
        .send({
          submissionId: 's1',
          decision: 'REJECTED',
          note: 'Please retake the selfie',
        })
        .expect(200);
      expect(kycService.review).toHaveBeenCalledWith('business-1', {
        submissionId: 's1',
        decision: 'REJECTED',
        note: 'Please retake the selfie',
      });
    });
  });

  describe('KycAccessGuard current token rules', () => {
    const jwt = { verifyAsync: jest.fn() };
    const prisma = { user: { findUnique: jest.fn() } };
    const guard = new KycAccessGuard(jwt as never, prisma as never);

    function context(authorization?: string) {
      const request: { headers: { authorization?: string }; user?: unknown } = {
        headers: { authorization },
      };
      return {
        switchToHttp: () => ({
          getRequest: () => request,
        }),
      } as unknown as ExecutionContext;
    }

    beforeEach(() => {
      jwt.verifyAsync.mockReset();
      prisma.user.findUnique.mockReset();
    });

    it('accepts a KYC_ONBOARDING token for a suspended client', async () => {
      jwt.verifyAsync.mockResolvedValue({
        sub: 'u1',
        version: 1,
        purpose: 'KYC_ONBOARDING',
      });
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        role: UserRole.CLIENT,
        status: UserStatus.SUSPENDED,
        authVersion: 1,
      });
      const ctx = context('Bearer kyc-token');
      await expect(guard.canActivate(ctx)).resolves.toBe(true);
      expect(ctx.switchToHttp().getRequest().user).toMatchObject({
        userId: 'u1',
        onboarding: true,
      });
    });

    it('accepts a normal session token only when the client is ACTIVE', async () => {
      jwt.verifyAsync.mockResolvedValue({ sub: 'u1', version: 1 });
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        role: UserRole.CLIENT,
        status: UserStatus.ACTIVE,
        authVersion: 1,
      });
      await expect(guard.canActivate(context('Bearer session'))).resolves.toBe(
        true,
      );
    });

    it('rejects a session token when the client is still SUSPENDED', async () => {
      jwt.verifyAsync.mockResolvedValue({ sub: 'u1', version: 1 });
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        role: UserRole.CLIENT,
        status: UserStatus.SUSPENDED,
        authVersion: 1,
      });
      await expect(guard.canActivate(context('Bearer session'))).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });

  describe('KycService review and resubmit rules', () => {
    const prisma = {
      user: { findUnique: jest.fn() },
      $executeRaw: jest.fn(),
      $queryRaw: jest.fn(),
      $transaction: jest.fn(),
      notification: { create: jest.fn() },
      bankAccount: {
        findFirst: jest.fn(),
        count: jest.fn(),
        create: jest.fn(),
      },
    };
    const objects = { putKyc: jest.fn(), get: jest.fn(), remove: jest.fn() };
    const service = new KycService(prisma as never, objects as never);

    beforeEach(() => {
      jest.resetAllMocks();
      prisma.$transaction.mockImplementation(async (fn: (tx: typeof prisma) => unknown) =>
        fn(prisma),
      );
    });

    it('activates the user on APPROVED and stores the review note on REJECTED', async () => {
      prisma.$queryRaw.mockResolvedValue([
        {
          id: 's1',
          userId: 'u1',
          businessUserId: 'biz',
          status: 'PENDING',
          bankDetails: null,
        },
      ]);
      prisma.$executeRaw.mockResolvedValue(1);

      await expect(
        service.review('biz', { submissionId: 's1', decision: 'APPROVED' }),
      ).resolves.toEqual({ reviewed: true, status: 'APPROVED' });
      expect(JSON.stringify(prisma.$executeRaw.mock.calls)).toContain('ACTIVE');

      prisma.$executeRaw.mockClear();
      await expect(
        service.review('biz', {
          submissionId: 's1',
          decision: 'REJECTED',
          note: 'Blurry PAN',
        }),
      ).resolves.toEqual({ reviewed: true, status: 'REJECTED' });
      expect(JSON.stringify(prisma.$executeRaw.mock.calls)).toContain('Blurry PAN');
      expect(JSON.stringify(prisma.$executeRaw.mock.calls)).not.toContain('ACTIVE');
    });

    it('does not let another business user review the submission', async () => {
      prisma.$queryRaw.mockResolvedValue([]);
      await expect(
        service.review('other-biz', { submissionId: 's1', decision: 'APPROVED' }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('rejects an invalid review decision', async () => {
      await expect(
        service.review('biz', {
          submissionId: 's1',
          decision: 'PENDING' as 'APPROVED',
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('rejects missing personal or bank details before storing files', async () => {
      await expect(
        service.submit('u1', {
          documentType: 'PAN',
          fileName: 'pan.png',
          mimeType: 'image/png',
          contentBase64: 'eA==',
          selfieContentBase64: 'eA==',
          selfieMimeType: 'image/png',
          signatureContentBase64: 'eA==',
        } as never),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(objects.putKyc).not.toHaveBeenCalled();
    });

    it('blocks a second submit while PENDING and allows submit after REJECTED', async () => {
      const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ZkAAAAASUVORK5CYII=';
      const input = {
        fullName: 'Test Customer',
        bankDetails: {
          accountHolder: 'Test Customer',
          bankName: 'Test Bank',
          accountNumber: '123456789',
          ifscCode: 'SBIN0001234',
        },
        documentType: 'PAN' as const,
        fileName: 'pan.png',
        mimeType: 'image/png',
        contentBase64: png,
        selfieContentBase64: png,
        selfieMimeType: 'image/png',
        signatureContentBase64: png,
      };
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        assignedBusinessId: 'biz',
      });
      objects.putKyc.mockResolvedValue({ key: 'private/1', mime: 'image/png' });
      prisma.$queryRaw.mockResolvedValue([{ id: 'existing-pending' }]);
      await expect(service.submit('u1', input)).rejects.toBeInstanceOf(
        BadRequestException,
      );

      prisma.$queryRaw.mockResolvedValue([]);
      objects.putKyc
        .mockResolvedValueOnce({ key: 'private/selfie', mime: 'image/png' })
        .mockResolvedValueOnce({ key: 'private/sig', mime: 'image/png' })
        .mockResolvedValueOnce({ key: 'private/front', mime: 'image/png' });
      await expect(service.submit('u1', input)).resolves.toMatchObject({
        status: 'PENDING',
      });
    });
  });
});
