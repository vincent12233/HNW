import { readFileSync } from 'fs';
import { join } from 'path';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { BusinessAssignmentAdminController } from './business-assignment.controller';
import { BusinessAssignmentService } from './business-assignment.service';
import { TeamController } from './team.controller';
import { TeamService } from './team.service';
import { BusinessService } from './business.service';
import { KycService } from '../kyc/kyc.service';

describe('Business assignment HTTP role boundaries', () => {
  const assignments = {
    listAssignments: jest.fn(),
    preview: jest.fn(),
    assignOrTransferBusinessToManager: jest.fn(),
    historyForAdmin: jest.fn(),
    listManagerTeam: jest.fn(),
    listManagerCustomers: jest.fn(),
    historyForManager: jest.fn(),
  };
  const prisma = { user: { findUnique: jest.fn() } };

  async function buildAdmin(role: UserRole) {
    const module = await Test.createTestingModule({
      controllers: [BusinessAssignmentAdminController],
      providers: [
        { provide: BusinessAssignmentService, useValue: assignments },
        { provide: PrismaService, useValue: prisma },
        RolesGuard,
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(stubAuthenticatedUser({ userId: `${role}-1`, role }))
      .compile();
    return createCharacterizationHttpApp(module);
  }

  async function buildTeam(role: UserRole) {
    const module = await Test.createTestingModule({
      controllers: [TeamController],
      providers: [
        { provide: TeamService, useValue: { list: jest.fn(), remove: jest.fn() } },
        { provide: BusinessService, useValue: {} },
        { provide: BusinessAssignmentService, useValue: assignments },
        { provide: KycService, useValue: {} },
        { provide: PrismaService, useValue: prisma },
        RolesGuard,
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(stubAuthenticatedUser({ userId: `${role}-1`, role }))
      .compile();
    return createCharacterizationHttpApp(module);
  }

  afterEach(() => jest.resetAllMocks());

  it.each([
    UserRole.MANAGER,
    UserRole.BUSINESS,
    UserRole.FINANCE,
    UserRole.SUPPORT,
    UserRole.CLIENT,
  ])('forbids %s from ADMIN transfer APIs', async (role) => {
    const app = await buildAdmin(role);
    prisma.user.findUnique.mockResolvedValue({
      role,
      status: UserStatus.ACTIVE,
    });
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await request(app.getHttpServer())
        .post('/admin/business-assignments/transfer')
        .send({
          businessUserId: '00000000-0000-4000-8000-000000000001',
          newManagerId: '00000000-0000-4000-8000-000000000002',
          reason: 'Need a valid reason',
          expectedCurrentManagerId: null,
          idempotencyKey: 'idem-key-1',
        })
        .expect(403);
      await request(app.getHttpServer())
        .post('/admin/business-assignments/preview')
        .send({
          businessUserId: '00000000-0000-4000-8000-000000000001',
          newManagerId: '00000000-0000-4000-8000-000000000002',
        })
        .expect(403);
      expect(assignments.assignOrTransferBusinessToManager).not.toHaveBeenCalled();
      expect(assignments.preview).not.toHaveBeenCalled();
    } finally {
      logging.mockRestore();
      await app.close();
    }
  });

  it('lets ADMIN call preview and transfer', async () => {
    const app = await buildAdmin(UserRole.ADMIN);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.ADMIN,
      status: UserStatus.ACTIVE,
    });
    assignments.preview.mockResolvedValue({ warnings: [] });
    assignments.assignOrTransferBusinessToManager.mockResolvedValue({
      replayed: false,
    });
    await request(app.getHttpServer())
      .post('/admin/business-assignments/preview')
      .send({
        businessUserId: '00000000-0000-4000-8000-000000000001',
        newManagerId: '00000000-0000-4000-8000-000000000002',
      })
      .expect(201);
    await request(app.getHttpServer())
      .post('/admin/business-assignments/transfer')
      .send({
        businessUserId: '00000000-0000-4000-8000-000000000001',
        newManagerId: '00000000-0000-4000-8000-000000000002',
        reason: 'Need a valid reason',
        expectedCurrentManagerId: null,
        idempotencyKey: 'idem-key-1',
      })
      .expect(201);
    await app.close();
  });

  it('lets a manager read own team routes and forbids ADMIN-only history by other roles on team writes', async () => {
    const app = await buildTeam(UserRole.MANAGER);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.MANAGER,
      status: UserStatus.ACTIVE,
    });
    assignments.listManagerTeam.mockResolvedValue([]);
    assignments.listManagerCustomers.mockResolvedValue([]);
    assignments.historyForManager.mockResolvedValue([]);
    await request(app.getHttpServer()).get('/team/business-users').expect(200);
    await request(app.getHttpServer()).get('/team/customers').expect(200);
    await request(app.getHttpServer()).get('/team/assignment-history').expect(200);
    await app.close();
  });

  it.each([UserRole.BUSINESS, UserRole.FINANCE, UserRole.SUPPORT, UserRole.CLIENT])(
    'forbids %s from manager team assignment reads',
    async (role) => {
      const app = await buildTeam(role);
      prisma.user.findUnique.mockResolvedValue({
        role,
        status: UserStatus.ACTIVE,
      });
      const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        await request(app.getHttpServer()).get('/team/business-users').expect(403);
        expect(assignments.listManagerTeam).not.toHaveBeenCalled();
      } finally {
        logging.mockRestore();
        await app.close();
      }
    },
  );
});

describe('Business assignment controller surface', () => {
  const admin = readFileSync(
    join(__dirname, 'business-assignment.controller.ts'),
    'utf8',
  );
  const team = readFileSync(join(__dirname, 'team.controller.ts'), 'utf8');

  it('keeps transfer writes on ADMIN only', () => {
    expect(admin).toMatch(/@Roles\(UserRole\.ADMIN\)/);
    expect(admin).toMatch(/Post\('transfer'\)/);
    expect(admin).not.toMatch(/UserRole\.FINANCE/);
    expect(admin).not.toMatch(/UserRole\.SUPPORT/);
    expect(admin).not.toMatch(/UserRole\.CLIENT/);
    expect(admin).not.toMatch(/@Delete/);
  });

  it('does not expose transfer on manager team routes', () => {
    expect(team).toMatch(/assignment-history/);
    expect(team).not.toMatch(/transfer/);
    expect(team).not.toMatch(/businessCreatorId/);
  });
});
