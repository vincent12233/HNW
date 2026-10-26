import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, type RedisClientType } from 'redis';

@Injectable()
export class RedisHealthService implements OnModuleInit, OnModuleDestroy {
  private client?: RedisClientType;
  private connected = false;

  constructor(private readonly config: ConfigService) {}

  async onModuleInit(): Promise<void> {
    const url = this.config.get<string>('RATE_LIMIT_REDIS_URL')?.trim();
    if (!url) return;
    this.client = createClient({
      url,
      socket: { connectTimeout: 3000, reconnectStrategy: false },
    });
    this.client.on('error', () => {
      this.connected = false;
    });
    try {
      await this.client.connect();
      this.connected = (await this.client.ping()) === 'PONG';
    } catch {
      this.connected = false;
    }
  }

  status() {
    return {
      configured: Boolean(this.client),
      connected: this.connected && this.client?.isReady === true,
    };
  }

  async onModuleDestroy(): Promise<void> {
    if (this.client?.isOpen) await this.client.quit();
  }
}
