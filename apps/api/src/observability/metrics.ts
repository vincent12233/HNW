export type HttpMetricSnapshot = {
  requests: number;
  errors4xx: number;
  errors5xx: number;
  totalDurationMs: number;
};

const snapshot: HttpMetricSnapshot = {
  requests: 0,
  errors4xx: 0,
  errors5xx: 0,
  totalDurationMs: 0,
};
const businessFailures = new Map<string, number>();
const businessEvents = new Map<string, number>();
const operationalCounters = new Map<string, number>();
const operationalGauges = new Map<string, number>();

export function recordHttpMetric(statusCode: number, durationMs: number): void {
  snapshot.requests += 1;
  snapshot.totalDurationMs += durationMs;
  if (statusCode >= 500) snapshot.errors5xx += 1;
  else if (statusCode >= 400) snapshot.errors4xx += 1;
}

export function recordBusinessEvent(event: string): void {
  businessEvents.set(event, (businessEvents.get(event) ?? 0) + 1);
}

export function recordBusinessFailure(event: string): void {
  businessFailures.set(event, (businessFailures.get(event) ?? 0) + 1);
}

export function recordOperationalCounter(name: string, increment = 1): void {
  operationalCounters.set(
    name,
    (operationalCounters.get(name) ?? 0) + increment,
  );
}

export function setOperationalGauge(name: string, value: number): void {
  operationalGauges.set(name, value);
}

export async function observeExternalCall<T>(
  provider: string,
  operation: string,
  action: () => Promise<T>,
): Promise<T> {
  const metric = `external_${provider}_${operation}`;
  recordOperationalCounter(`${metric}_attempted`);
  const startedAt = Date.now();
  try {
    const result = await action();
    recordOperationalCounter(`${metric}_succeeded`);
    return result;
  } catch (error) {
    recordOperationalCounter(`${metric}_failed`);
    throw error;
  } finally {
    recordOperationalCounter(
      `${metric}_duration_ms_total`,
      Date.now() - startedAt,
    );
  }
}

export function getHttpMetricSnapshot(): HttpMetricSnapshot {
  return { ...snapshot };
}

function prometheusLabel(value: string): string {
  return value.replace(/[^a-zA-Z0-9_:]/g, '_');
}

export function renderPrometheusMetrics(): string {
  const memory = process.memoryUsage();
  const http = getHttpMetricSnapshot();
  const averageDurationMs = http.requests
    ? http.totalDurationMs / http.requests
    : 0;
  const businessLines = [...businessFailures.entries()].map(
    ([event, count]) =>
      `hnw_business_failures_total{event="${prometheusLabel(event)}"} ${count}`,
  );
  const businessEventLines = [...businessEvents.entries()].map(
    ([event, count]) =>
      `hnw_business_events_total{event="${prometheusLabel(event)}"} ${count}`,
  );
  const operationalCounterLines = [...operationalCounters.entries()].map(
    ([event, count]) =>
      `hnw_operational_counters_total{event="${prometheusLabel(event)}"} ${count}`,
  );
  const operationalGaugeLines = [...operationalGauges.entries()].map(
    ([metric, value]) =>
      `hnw_operational_gauge{metric="${prometheusLabel(metric)}"} ${value}`,
  );
  return [
    '# HELP hnw_process_uptime_seconds Process uptime in seconds.',
    '# TYPE hnw_process_uptime_seconds gauge',
    `hnw_process_uptime_seconds ${process.uptime()}`,
    '# HELP hnw_process_resident_memory_bytes Resident memory in bytes.',
    '# TYPE hnw_process_resident_memory_bytes gauge',
    `hnw_process_resident_memory_bytes ${memory.rss}`,
    '# HELP hnw_http_requests_total Total HTTP requests handled.',
    '# TYPE hnw_http_requests_total counter',
    `hnw_http_requests_total ${http.requests}`,
    '# HELP hnw_http_errors_total HTTP errors by status class.',
    '# TYPE hnw_http_errors_total counter',
    `hnw_http_errors_total{class="4xx"} ${http.errors4xx}`,
    `hnw_http_errors_total{class="5xx"} ${http.errors5xx}`,
    '# HELP hnw_http_request_duration_average_ms Average HTTP duration in milliseconds.',
    '# TYPE hnw_http_request_duration_average_ms gauge',
    `hnw_http_request_duration_average_ms ${averageDurationMs}`,
    '# HELP hnw_business_events_total Successful critical business events.',
    '# TYPE hnw_business_events_total counter',
    ...businessEventLines,
    '# HELP hnw_business_failures_total Rejected requests on critical business routes.',
    '# TYPE hnw_business_failures_total counter',
    ...businessLines,
    '# HELP hnw_operational_counters_total Operational event counters.',
    '# TYPE hnw_operational_counters_total counter',
    ...operationalCounterLines,
    '# HELP hnw_operational_gauge Current operational gauges.',
    '# TYPE hnw_operational_gauge gauge',
    ...operationalGaugeLines,
    '',
  ].join('\n');
}
