import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { ErrorIngestionController } from './error-ingestion.controller';
import { ErrorIngestionService } from './error-ingestion.service';

describe('Error ingestion HTTP contract', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [ErrorIngestionController],
      providers: [ErrorIngestionService],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
    await app.init();
  });

  afterAll(async () => app.close());

  it('accepts sanitized client reports', async () => {
    await request(app.getHttpServer())
      .post('/observability/client-errors')
      .send({
        event: 'admin_error',
        operation: 'GET /accounts',
        error: 'Error',
        fingerprint: 'abc123',
        message: 'Request failed',
        timestamp: '2026-09-27T00:00:00.000Z',
      })
      .expect(202)
      .expect(({ body }) => expect(body.accepted).toBe(true));
  });

  it('rejects unknown report types and oversized fields', async () => {
    await request(app.getHttpServer())
      .post('/observability/client-errors')
      .send({
        event: 'raw_exception',
        operation: 'x'.repeat(300),
        error: 'Error',
        fingerprint: 'abc',
        message: 'failed',
        timestamp: '2026-09-27T00:00:00.000Z',
      })
      .expect(400);
  });
});
