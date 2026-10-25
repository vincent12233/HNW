import { randomUUID } from 'node:crypto';
import { createClient, type RedisClientType } from 'redis';

const RELEASE_SCRIPT = `
if redis.call('GET', KEYS[1]) == ARGV[1] then
  return redis.call('DEL', KEYS[1])
end
return 0
`;

export type AcquiredRedisLease = {
  resource: string;
  owner: string;
  token: string;
  release(): Promise<boolean>;
};

export class RedisLease {
  constructor(private readonly client: Pick<RedisClientType, 'set' | 'eval'>) {}

  async acquire(
    resource: string,
    ttlMs: number,
    owner: string,
  ): Promise<AcquiredRedisLease | null> {
    if (
      !resource.trim() ||
      !owner.trim() ||
      ttlMs < 1000 ||
      ttlMs > 3_600_000
    ) {
      throw new Error('Invalid Redis lease request');
    }
    const key = `hnw:lease:${resource}`;
    const token = `${owner}:${randomUUID()}`;
    const acquired = await this.client.set(key, token, { NX: true, PX: ttlMs });
    if (acquired !== 'OK') return null;
    return {
      resource,
      owner,
      token,
      release: async () =>
        Number(
          await this.client.eval(RELEASE_SCRIPT, {
            keys: [key],
            arguments: [token],
          }),
        ) === 1,
    };
  }
}

export async function connectRedisLease(url: string) {
  const client = createClient({
    url,
    commandsQueueMaxLength: 1000,
    socket: {
      connectTimeout: 5_000,
      reconnectStrategy: (attempt) =>
        attempt >= 5
          ? new Error('Redis lease reconnect limit reached')
          : Math.min(2000, attempt * 250),
    },
  });
  await client.connect();
  return { lease: new RedisLease(client), close: () => client.quit() };
}
