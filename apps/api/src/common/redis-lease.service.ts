import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { hostname } from 'node:os';
import { connectRedisLease, RedisLease } from './redis-lease';

@Injectable()
export class RedisLeaseService implements OnModuleInit, OnModuleDestroy {
  private lease?: RedisLease;
  private close?: () => Promise<unknown>;
  private readonly owner = `${hostname()}:${process.pid}`;

  constructor(private readonly config: ConfigService) {}

  async onModuleInit(): Promise<void> {
    const url = this.config.get<string>('RATE_LIMIT_REDIS_URL')?.trim();
    if (!url) return;
    const connected = await connectRedisLease(url);
    this.lease = connected.lease;
    this.close = connected.close;
  }

  async runExclusive<T>(
    resource: string,
    ttlMs: number,
    action: () => Promise<T>,
  ): Promise<T | undefined> {
    if (!this.lease) return action();
    const acquired = await this.lease.acquire(resource, ttlMs, this.owner);
    if (!acquired) return undefined;
    try {
      return await action();
    } finally {
      await acquired.release();
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.close?.();
  }
}
