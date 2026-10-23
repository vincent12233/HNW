import { ForbiddenException } from '@nestjs/common';
import type { ExecutionContext } from '@nestjs/common';
import { MetricsAccessGuard } from './metrics-access.guard';

describe('MetricsAccessGuard', () => {
  const previousNodeEnv = process.env.NODE_ENV;
  const previousToken = process.env.METRICS_BEARER_TOKEN;

  const context = (ip: string, authorization?: string) =>
    ({
      switchToHttp: () => ({
        getRequest: () => ({
          ip,
          socket: { remoteAddress: ip },
          header: (name: string) =>
            name.toLowerCase() === 'authorization' ? authorization : undefined,
        }),
      }),
    }) as ExecutionContext;

  afterEach(() => {
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousToken === undefined) delete process.env.METRICS_BEARER_TOKEN;
    else process.env.METRICS_BEARER_TOKEN = previousToken;
  });

  it('keeps local development metrics available', () => {
    process.env.NODE_ENV = 'development';
    expect(new MetricsAccessGuard().canActivate(context('203.0.113.10'))).toBe(
      true,
    );
  });

  it.each(['127.0.0.1', '::1', '::ffff:172.20.0.4', '10.0.0.8'])(
    'allows the production scraper from private address %s',
    (ip) => {
      process.env.NODE_ENV = 'production';
      expect(new MetricsAccessGuard().canActivate(context(ip))).toBe(true);
    },
  );

  it('rejects public production requests without monitoring credentials', () => {
    process.env.NODE_ENV = 'production';
    expect(() =>
      new MetricsAccessGuard().canActivate(context('203.0.113.10')),
    ).toThrow(ForbiddenException);
  });

  it('accepts the configured monitoring bearer token using exact matching', () => {
    process.env.NODE_ENV = 'production';
    process.env.METRICS_BEARER_TOKEN = 'm'.repeat(32);
    expect(
      new MetricsAccessGuard().canActivate(
        context('203.0.113.10', `Bearer ${'m'.repeat(32)}`),
      ),
    ).toBe(true);
    expect(() =>
      new MetricsAccessGuard().canActivate(
        context('203.0.113.10', `Bearer ${'m'.repeat(31)}x`),
      ),
    ).toThrow(ForbiddenException);
  });
});
