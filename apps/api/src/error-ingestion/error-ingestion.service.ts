import { Injectable, Logger } from '@nestjs/common';
import { redactSensitiveText } from '../observability/error-report';
import { recordOperationalCounter } from '../observability/metrics';
import { SubmitClientErrorDto } from './dto/submit-client-error.dto';

@Injectable()
export class ErrorIngestionService {
  private readonly logger = new Logger(ErrorIngestionService.name);

  accept(input: SubmitClientErrorDto) {
    const report = {
      event: input.event,
      operation: redactSensitiveText(input.operation).slice(0, 256),
      error: redactSensitiveText(input.error).slice(0, 128),
      fingerprint: redactSensitiveText(input.fingerprint).slice(0, 64),
      message: redactSensitiveText(input.message),
      ...(input.stack ? { stack: redactSensitiveText(input.stack) } : {}),
      ...(input.statusCode ? { statusCode: input.statusCode } : {}),
      ...(input.requestId
        ? { requestId: redactSensitiveText(input.requestId).slice(0, 128) }
        : {}),
      timestamp: input.timestamp,
      receivedAt: new Date().toISOString(),
    };
    recordOperationalCounter(`${input.event}_received`);
    this.logger.warn(JSON.stringify(report));
    void this.forward(report);
    return { accepted: true, fingerprint: report.fingerprint };
  }

  private async forward(report: Record<string, unknown>) {
    const endpoint = process.env.ERROR_REPORT_WEBHOOK_URL?.trim();
    if (!endpoint) return;
    try {
      const url = new URL(endpoint);
      if (process.env.NODE_ENV === 'production' && url.protocol !== 'https:') {
        throw new Error(
          'ERROR_REPORT_WEBHOOK_URL must use HTTPS in production',
        );
      }
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          ...(process.env.ERROR_REPORT_WEBHOOK_TOKEN
            ? {
                authorization: `Bearer ${process.env.ERROR_REPORT_WEBHOOK_TOKEN}`,
              }
            : {}),
        },
        body: JSON.stringify(report),
        signal: AbortSignal.timeout(3000),
      });
      if (!response.ok) throw new Error(`webhook returned ${response.status}`);
      recordOperationalCounter('error_report_forwarded');
    } catch (error) {
      recordOperationalCounter('error_report_forward_failed');
      this.logger.error(
        `Error report forwarding failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }
  }
}
