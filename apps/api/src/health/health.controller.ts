import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

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
    await this.prisma.$queryRaw`SELECT 1`;
    return {
      status: 'ready',
      database: 'connected',
      timestamp: new Date().toISOString(),
    };
  }
}
