import {
  MemoryRateLimitStore,
  RedisRateLimitStore,
  normalizeRateLimitPath,
} from './rate-limit-store';

describe('rate limit store', () => {
  it('increments counters within the same window', async () => {
    const store = new MemoryRateLimitStore();
    expect((await store.consume('client', 60_000)).count).toBe(1);
    expect((await store.consume('client', 60_000)).count).toBe(2);
  });

  it('normalizes numeric and UUID resource identifiers', () => {
    expect(normalizeRateLimitPath('/orders/123/cancel')).toBe(
      '/orders/:id/cancel',
    );
    expect(
      normalizeRateLimitPath(
        '/customers/123e4567-e89b-12d3-a456-426614174000/kyc',
      ),
    ).toBe('/customers/:id/kyc');
  });
});

const redisTest = process.env.HNW_VERIFY_REDIS === '1' ? it : it.skip;

redisTest('shares counters between Redis-backed API instances', async () => {
  const url = process.env.RATE_LIMIT_REDIS_URL as string;
  const first = await RedisRateLimitStore.connect(url);
  const second = await RedisRateLimitStore.connect(url);
  const key = `test:${Date.now()}:${Math.random()}`;
  try {
    expect((await first.consume(key, 60_000)).count).toBe(1);
    expect((await second.consume(key, 60_000)).count).toBe(2);
  } finally {
    await Promise.all([first.close(), second.close()]);
  }
});
