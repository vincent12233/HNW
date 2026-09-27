export type AdminErrorReport = {
  event: 'admin_error';
  operation: string;
  statusCode?: number;
  requestId?: string;
  error: string;
  fingerprint: string;
  message: string;
  timestamp: string;
};

type ErrorContext = {
  operation: string;
  statusCode?: number;
  requestId?: string;
};

export function redactTelemetryText(value: string): string {
  return value
    .replace(/Bearer\s+[A-Za-z0-9._~+/-]+=*/gi, 'Bearer [REDACTED]')
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, '[JWT]')
    .replace(
      /([?&](?:access_token|id_token|refresh_token|token|password|secret|code)=)[^&#\s]+/gi,
      '$1[REDACTED]',
    )
    .replace(
      /((?:access_token|id_token|refresh_token|token|password|secret|authorization)\s*[:=]\s*)[^\s,;]+/gi,
      '$1[REDACTED]',
    )
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[EMAIL]')
    .replace(/(?:\+?\d[\s-]?){10,15}/g, '[PHONE]')
    .replace(/[A-Za-z]:\\Users\\[^\\\s]+/gi, '[USER_HOME]')
    .replace(/\/Users\/[^/\s]+/g, '[USER_HOME]')
    .replace(/\/home\/[^/\s]+/g, '[USER_HOME]')
    .replace(/\b[A-Za-z0-9+/]{160,}={0,2}\b/g, '[ENCODED_DATA]')
    .slice(0, 2000);
}

function fingerprint(value: string): string {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

export function createAdminErrorReport(
  error: unknown,
  context: ErrorContext,
): AdminErrorReport {
  const errorName = error instanceof Error ? error.name : 'UnknownError';
  const message = redactTelemetryText(
    error instanceof Error ? error.message : String(error),
  );
  const operation = redactTelemetryText(context.operation);
  return {
    event: 'admin_error',
    operation,
    statusCode: context.statusCode,
    requestId: context.requestId,
    error: errorName,
    fingerprint: fingerprint(`${errorName}\n${operation}\n${message}`),
    message,
    timestamp: new Date().toISOString(),
  };
}

export function reportAdminError(error: unknown, context: ErrorContext): void {
  if (typeof window === 'undefined') return;
  const report = createAdminErrorReport(error, context);
  window.dispatchEvent(
    new CustomEvent<AdminErrorReport>('admin-error-report', { detail: report }),
  );
  const baseUrl = process.env.NEXT_PUBLIC_API_URL?.trim();
  if (!baseUrl) return;
  void fetch(`${baseUrl}/observability/client-errors`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(report),
    keepalive: true,
  }).catch(() => undefined);
}
