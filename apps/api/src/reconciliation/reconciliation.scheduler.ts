import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ReconciliationService } from './reconciliation.service';

@Injectable()
export class ReconciliationScheduler {
  private readonly logger = new Logger(ReconciliationScheduler.name);

  constructor(private readonly reconciliation: ReconciliationService) {}

  @Cron('0 */15 * * * *', { name: 'financial-reconciliation' })
  async reconcile(): Promise<void> {
    try {
      const result = await this.reconciliation.run();
      if (!result.skipped && result.issueCount > 0) {
        this.logger.warn(
          `Reconciliation ${result.runId} found ${result.issueCount} issue(s)`,
        );
      }
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Financial reconciliation failed: ${message}`);
    }
  }
}
