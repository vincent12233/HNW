import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AllExceptionsFilter } from '../observability/all-exceptions.filter';
import { PrismaService } from '../prisma/prisma.service';
import { HealthController } from './health.controller';

describe('health probe HTTP contracts', () => {
  let app: INestApplication;
  const query = jest.fn();

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [{ provide: PrismaService, useValue: { $queryRaw: query } }],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.init();
  });

  beforeEach(() => query.mockReset());
  afterAll(async () => app.close());

  it('keeps liveness independent of database availability', async () => {
    query.mockRejectedValue(new Error('database unavailable'));
    await request(app.getHttpServer())
      .get('/health/live')
      .expect(200)
      .expect(({ body }) => expect(body.status).toBe('ok'));
    expect(query).not.toHaveBeenCalled();
  });

  it('reports ready only after a successful database probe', async () => {
    query.mockResolvedValue([{ '?column?': 1 }]);
    await request(app.getHttpServer())
      .get('/health/ready')
      .expect(200)
      .expect(({ body }) => {
        expect(body.status).toBe('ready');
        expect(body.database).toBe('connected');
      });
    expect(query).toHaveBeenCalledTimes(1);
  });

  it('reports 503 without leaking database details, and recovers on the next probe', async () => {
    query
      .mockRejectedValueOnce(
        new Error('cannot connect: postgresql://private-credentials@db'),
      )
      .mockResolvedValueOnce([{ '?column?': 1 }]);
    const logging = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const failed = await request(app.getHttpServer())
        .get('/health/ready')
        .expect(503);
      expect(failed.body.statusCode).toBe(503);
      expect(JSON.stringify(failed.body)).not.toContain('private-credentials');
      await request(app.getHttpServer()).get('/health/ready').expect(200);
    } finally {
      logging.mockRestore();
    }
  });
});
