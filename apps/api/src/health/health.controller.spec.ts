import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AllExceptionsFilter } from '../observability/all-exceptions.filter';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';

describe('health probe HTTP contracts', () => {
  let app: INestApplication;
  const probeDatabase = jest.fn();
  const evaluateTradingReady = jest.fn();

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        {
          provide: HealthService,
          useValue: { probeDatabase, evaluateTradingReady },
        },
      ],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.init();
  });

  beforeEach(() => {
    probeDatabase.mockReset();
    evaluateTradingReady.mockReset();
  });
  afterAll(async () => app.close());

  it('keeps liveness independent of database availability', async () => {
    probeDatabase.mockRejectedValue(new Error('database unavailable'));
    await request(app.getHttpServer())
      .get('/health/live')
      .expect(200)
      .expect(({ body }) => expect(body.status).toBe('ok'));
    expect(probeDatabase).not.toHaveBeenCalled();
  });

  it('reports ready only after a successful database probe', async () => {
    probeDatabase.mockResolvedValue(undefined);
    await request(app.getHttpServer())
      .get('/health/ready')
      .expect(200)
      .expect(({ body }) => {
        expect(body.status).toBe('ready');
        expect(body.database).toBe('connected');
      });
    expect(probeDatabase).toHaveBeenCalledTimes(1);
  });

  it('reports 503 without leaking database details, and recovers on the next probe', async () => {
    probeDatabase
      .mockRejectedValueOnce(
        new Error('cannot connect: postgresql://private-credentials@db'),
      )
      .mockResolvedValueOnce(undefined);
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

  it('exposes trading-ready as a dedicated gate with structured status', async () => {
    evaluateTradingReady.mockResolvedValue({
      statusCode: 503,
      body: {
        status: 'unavailable',
        tradingReady: false,
        marketOpen: true,
        reason: 'MARKET_DATA_STALE',
        configuredProvider: 'APIFY',
        providerConfigured: true,
      },
    });

    const response = await request(app.getHttpServer())
      .get('/health/trading-ready')
      .expect(503);

    expect(response.body.reason).toBe('MARKET_DATA_STALE');
    expect(JSON.stringify(response.body)).not.toContain('APIFY_TOKEN');
    expect(probeDatabase).not.toHaveBeenCalled();
  });
});
