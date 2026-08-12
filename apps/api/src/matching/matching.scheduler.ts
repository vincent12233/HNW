import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { MatchingScanService } from './matching-scan.service';

@Injectable()
export class MatchingScheduler {
  private readonly logger = new Logger(MatchingScheduler.name);
  private running = false;

  constructor(private readonly matchingScanService: MatchingScanService) {}

  @Cron(CronExpression.EVERY_SECOND, { name: 'open-order-matching' })
  async scanOpenOrders(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      await this.matchingScanService.scanOpenOrders();
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Open order scan failed: ${message}`);
    } finally {
      this.running = false;
    }
  }
}
