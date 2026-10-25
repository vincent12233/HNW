import { Injectable, Logger, Optional } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { MatchingScanService } from './matching-scan.service';
import { RedisLeaseService } from '../common/redis-lease.service';

@Injectable()
export class MatchingScheduler {
  private readonly logger = new Logger(MatchingScheduler.name);
  private running = false;

  constructor(
    private readonly matchingScanService: MatchingScanService,
    @Optional() private readonly leases?: RedisLeaseService,
  ) {}

  @Cron(CronExpression.EVERY_SECOND, { name: 'open-order-matching' })
  async scanOpenOrders(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      const scan = () => this.matchingScanService.scanOpenOrders();
      if (this.leases)
        await this.leases.runExclusive('matching-scan', 5000, scan);
      else await scan();
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Open order scan failed: ${message}`);
    } finally {
      this.running = false;
    }
  }
}
