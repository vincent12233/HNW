import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { MetricsController } from './metrics.controller';
import { recordBusinessEvent } from './metrics';

describe('MetricsController', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [MetricsController],
    }).compile();
    app = module.createNestApplication();
    await app.init();
  });

  afterAll(async () => app.close());

  it('exposes root Prometheus metrics including critical business events', async () => {
    recordBusinessEvent('order_submitted');
    const response = await request(app.getHttpServer())
      .get('/metrics')
      .expect(200);
    expect(response.headers['content-type']).toContain('text/plain');
    expect(response.text).toContain(
      'hnw_business_events_total{event="order_submitted"}',
    );
    expect(response.text).toContain('hnw_http_requests_total');
  });
});
