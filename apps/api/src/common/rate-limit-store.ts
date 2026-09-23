import { Logger } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { createClient, type RedisClientType } from 'redis';

export type RateLimitEntry = { count: number; resetAt: number };

export interface RateLimitStore {
  consume(key: string, windowMs: number): Promise<RateLimitEntry>;
  close(): Promise<void>;
}

export class MemoryRateLimitStore implements RateLimitStore {
  private readonly entries = new Map<string, RateLimitEntry>();

  consume(key: string, windowMs: number): Promise<RateLimitEntry> {
    const now = Date.now();
    const current = this.entries.get(key);
    const entry =
      !current || current.resetAt <= now
        ? { count: 0, resetAt: now + windowMs }
        : current;
    entry.count += 1;
    this.entries.set(key, entry);
    if (this.entries.size > 10_000) {
      for (const [entryKey, value] of this.entries) {
        if (value.resetAt <= now) this.entries.delete(entryKey);
      }
    }
    return Promise.resolve(entry);
  }

  close() {
    return Promise.resolve();
  }
}

const CONSUME_SCRIPT = `
local count = redis.call('INCR', KEYS[1])
local ttl = redis.call('PTTL', KEYS[1])
if count == 1 or ttl < 0 then
  redis.call('PEXPIRE', KEYS[1], ARGV[1])
  ttl = tonumber(ARGV[1])
end
return {count, ttl}
`;

export class RedisRateLimitStore implements RateLimitStore {
  private static readonly logger = new Logger(RedisRateLimitStore.name);

  private constructor(private readonly client: RedisClientType) {}

  static async connect(url: string) {
    const client = createClient({
      url,
      socket: {
        connectTimeout: 5_000,
        reconnectStrategy: (retries) =>
          retries >= 5
            ? new Error('Redis reconnect limit reached')
            : retries * 250,
      },
    });
    client.on('error', (error: Error) =>
      RedisRateLimitStore.logger.error(
        `Redis rate-limit store error: ${error.message}`,
      ),
    );
    await client.connect();
    await client.ping();
    return new RedisRateLimitStore(client);
  }

  async consume(key: string, windowMs: number): Promise<RateLimitEntry> {
    const keyHash = createHash('sha256').update(key).digest('hex');
    const result = (await this.client.eval(CONSUME_SCRIPT, {
      keys: [`hnw:rate-limit:${keyHash}`],
      arguments: [String(windowMs)],
    })) as [number, number];
    const [count, ttl] = result.map(Number);
    return { count, resetAt: Date.now() + Math.max(0, ttl) };
  }

  async close() {
    if (this.client.isOpen) await this.client.quit();
  }
}

export function normalizeRateLimitPath(path: string) {
  return path
    .replace(/[0-9a-f]{8}-[0-9a-f-]{27,}/gi, ':id')
    .replace(/\/\d+(?=\/|$)/g, '/:id');
}

export async function createRateLimitStore() {
  const redisUrl = process.env.RATE_LIMIT_REDIS_URL?.trim();
  if (redisUrl) return RedisRateLimitStore.connect(redisUrl);
  return new MemoryRateLimitStore();
}
