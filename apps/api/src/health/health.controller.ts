import {
  Controller,
  Get,
  Res,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { Response } from 'express';
import { HealthService } from './health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly health: HealthService) {}

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

  @Get('ready')
  async ready() {
    try {
      await this.health.probeDatabase();
    } catch (error) {
      throw new ServiceUnavailableException('Service is not ready', {
        cause: error,
      });
    }
    return {
      status: 'ready',
      database: 'connected',
      timestamp: new Date().toISOString(),
    };
  }

  @Get('trading-ready')
  async tradingReady(@Res() response: Response) {
    const result = await this.health.evaluateTradingReady();
    return response.status(result.statusCode).json(result.body);
  }
}
