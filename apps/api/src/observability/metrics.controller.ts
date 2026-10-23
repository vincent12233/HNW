import { Controller, Get, Header, UseGuards } from '@nestjs/common';
import { renderPrometheusMetrics } from './metrics';
import { MetricsAccessGuard } from './metrics-access.guard';

@Controller()
export class MetricsController {
  @Get('metrics')
  @UseGuards(MetricsAccessGuard)
  @Header('content-type', 'text/plain; version=0.0.4')
  @Header('cache-control', 'no-store')
  metrics() {
    return renderPrometheusMetrics();
  }
}
