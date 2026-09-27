import { createHash } from 'crypto';

export type ErrorReportContext = {
  requestId?: string;
  method?: string;
  path?: string;
  statusCode: number;
};

export function redactSensitiveText(value: string): string {
  return value
    .replace(/Bearer\s+[A-Za-z0-9._~+/-]+=*/gi, 'Bearer [REDACTED]')
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, '[JWT]')
    .replace(
      /([?&](?:access_token|id_token|refresh_token|token|password|secret|code)=)[^&#\s]+/gi,
      '$1[REDACTED]',
    )
    .replace(
      /(["']?(?:access_token|id_token|refresh_token|token|password|secret|authorization)["']?\s*[:=]\s*["'])[^"']+/gi,
      '$1[REDACTED]',
    )
    .replace(
      /((?:access_token|id_token|refresh_token|token|password|secret|authorization)\s*[:=]\s*)[^\s,;]+/gi,
      '$1[REDACTED]',
    )
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[EMAIL]')
    .replace(/(?<!\d)(?:\+?\d[\s-]?){10,15}(?!\d)/g, '[PHONE]')
    .replace(/[A-Za-z]:\\Users\\[^\\\s]+/gi, '[USER_HOME]')
    .replace(/\/Users\/[^/\s]+/g, '[USER_HOME]')
    .replace(/\/home\/[^/\s]+/g, '[USER_HOME]')
    .replace(/\b[A-Za-z0-9+/]{160,}={0,2}\b/g, '[ENCODED_DATA]')
    .slice(0, 4_000);
}

export function buildErrorReport(
  exception: unknown,
  context: ErrorReportContext,
) {
  const errorName =
    exception instanceof Error ? exception.name : 'UnknownError';
  const message = redactSensitiveText(
    exception instanceof Error ? exception.message : String(exception),
  );
  const stack =
    context.statusCode >= 500 && exception instanceof Error && exception.stack
      ? redactSensitiveText(exception.stack)
      : undefined;
  const fingerprint = createHash('sha256')
    .update(`${errorName}\n${message}\n${stack ?? ''}`)
    .digest('hex')
    .slice(0, 16);
  return {
    level: context.statusCode >= 500 ? 'error' : 'warn',
    event: 'unhandled_exception',
    requestId: context.requestId,
    method: context.method,
    path: context.path ? redactSensitiveText(context.path) : undefined,
    statusCode: context.statusCode,
    error: errorName,
    fingerprint,
    message,
    ...(stack ? { stack } : {}),
    timestamp: new Date().toISOString(),
  };
}
