import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { createCharacterizationHttpApp } from '../testing/create-http-app';
import { stubAuthenticatedUser } from '../testing/stub-auth.guard';
import { WatchlistController } from './watchlist.controller';
import { WatchlistService } from './watchlist.service';

describe('Current watchlist HTTP behavior', () => {
  let app: INestApplication;
  const watchlist = { list: jest.fn(), add: jest.fn(), remove: jest.fn() };
  const prisma = { user: { findUnique: jest.fn() } };

  async function build(role: UserRole) {
    const module = await Test.createTestingModule({
      controllers: [WatchlistController],
      providers: [
        { provide: WatchlistService, useValue: watchlist },
        { provide: PrismaService, useValue: prisma },
        RolesGuard,
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(
        stubAuthenticatedUser({ userId: `${role.toLowerCase()}-1`, role }),
      )
      .compile();
    return createCharacterizationHttpApp(module);
  }

  afterEach(async () => {
    jest.resetAllMocks();
    if (app) await app.close();
  });

  it('lets CLIENT list the current watchlist', async () => {
    app = await build(UserRole.CLIENT);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.CLIENT,
      status: UserStatus.ACTIVE,
    });
    watchlist.list.mockResolvedValue([]);
    await request(app.getHttpServer()).get('/watchlist').expect(200);
    expect(watchlist.list).toHaveBeenCalledWith('client-1');
  });

  it('forbids staff from the client watchlist API', async () => {
    app = await build(UserRole.ADMIN);
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.ADMIN,
      status: UserStatus.ACTIVE,
    });
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await request(app.getHttpServer()).get('/watchlist').expect(403);
      expect(watchlist.list).not.toHaveBeenCalled();
    } finally {
      logging.mockRestore();
    }
  });
});
