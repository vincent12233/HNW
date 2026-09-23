import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { UserRole } from '../generated/prisma/enums';
import { SESSION_TTL } from './session-policy';

describe('Current staff login cookie and role isolation', () => {
  let app: INestApplication;
  const authService = {
    login: jest.fn(),
    currentUser: jest.fn(),
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthService, useValue: authService }],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(stubAuthenticatedUser({ userId: 'admin-1', role: UserRole.ADMIN }))
      .compile();
    app = await createCharacterizationHttpApp(module);
  });

  beforeEach(() => {
    authService.login.mockReset();
    authService.currentUser.mockReset();
  });
  afterAll(async () => app.close());

  function staffLoginBody() {
    return {
      message: 'Login successful',
      accessToken: 'staff-access',
      refreshToken: 'staff-refresh',
      tokenType: 'Bearer',
      expiresIn: 86400,
      user: {
        id: 'admin-1',
        role: 'ADMIN',
        status: 'ACTIVE',
        fullName: 'Admin',
        phone: null,
      },
      account: null,
    };
  }

  it('sets an HttpOnly role cookie and omits tokens when staff login includes Origin', async () => {
    authService.login.mockResolvedValue(staffLoginBody());
    const response = await request(app.getHttpServer())
      .post('/auth/login')
      .set('Origin', 'http://localhost:3002')
      .set('x-backend-role', 'ADMIN')
      .send({ employeeNo: 'ADMIN01', password: 'password1' })
      .expect(201);

    expect(response.body.accessToken).toBeUndefined();
    expect(response.body.refreshToken).toBeUndefined();
    expect(response.body.user.role).toBe('ADMIN');
    expect(response.body.expiresIn).toBe(SESSION_TTL.access.seconds);
    const cookie = response.headers['set-cookie'];
    expect(cookie).toBeDefined();
    const serialized = Array.isArray(cookie) ? cookie.join(';') : String(cookie);
    expect(serialized).toMatch(/staff_access_admin=staff-access/);
    expect(serialized).toMatch(/HttpOnly/i);
    expect(serialized).toMatch(/SameSite=Lax/i);
    expect(serialized).toContain(`Max-Age=${SESSION_TTL.access.seconds}`);
  });

  it('keeps bearer tokens for staff login without Origin (non-browser clients)', async () => {
    authService.login.mockResolvedValue(staffLoginBody());
    const response = await request(app.getHttpServer())
      .post('/auth/login')
      .set('x-backend-role', 'ADMIN')
      .send({ employeeNo: 'ADMIN01', password: 'password1' })
      .expect(201);
    expect(response.body.accessToken).toBe('staff-access');
    expect(response.headers['set-cookie']).toBeUndefined();
  });

  it('returns 403 when the staff console role does not match the account role', async () => {
    authService.login.mockResolvedValue(staffLoginBody());
    const response = await request(app.getHttpServer())
      .post('/auth/login')
      .set('Origin', 'http://localhost:3005')
      .set('x-backend-role', 'FINANCE')
      .send({ employeeNo: 'ADMIN01', password: 'password1' })
      .expect(403);
    expect(response.body.message).toMatch(/ADMIN backend/);
    expect(response.body.accessToken).toBeUndefined();
  });
});
