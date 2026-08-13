import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  check() {
    return {
      status: 'ok',
      api: 'running',
      timestamp: new Date().toISOString(),
    };
  }
}
