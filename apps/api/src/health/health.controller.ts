import {
  Controller,
  Get,
  Header,
  Optional,
  ServiceUnavailableException,
  UseGuards,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { renderPrometheusMetrics } from '../observability/metrics';
import { MetricsAccessGuard } from '../observability/metrics-access.guard';
import { RedisHealthService } from '../common/redis-health.service';

@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly redis?: RedisHealthService,
  ) {}

  @Get()
  check() {
    return {
      status: 'ok',
      api: 'running',
      timestamp: new Date().toISOString(),
    };
  }

  @Get('live')
  live() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }

  @Get('version')
  version() {
    return {
      version: process.env.npm_package_version ?? 'unknown',
      commit: process.env.GIT_COMMIT ?? 'unknown',
      builtAt: process.env.BUILD_TIME ?? 'unknown',
    };
  }

  @Get('metrics')
  @UseGuards(MetricsAccessGuard)
  @Header('content-type', 'text/plain; version=0.0.4')
  @Header('cache-control', 'no-store')
  metrics() {
    return renderPrometheusMetrics();
  }

  @Get('ready')
  async ready() {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      const redis = this.redis?.status();
      if (redis?.configured && !redis.connected) {
        throw new Error('Required Redis dependency is unavailable');
      }
    } catch (error) {
      throw new ServiceUnavailableException('Service is not ready', {
        cause: error,
      });
    }
    const redis = this.redis?.status() ?? {
      configured: false,
      connected: false,
    };
    return {
      status: 'ready',
      database: 'connected',
      redis,
      timestamp: new Date().toISOString(),
    };
  }
}
