import { observeExternalCall, renderPrometheusMetrics } from './metrics';

describe('operational metrics', () => {
  it('records successful external calls and duration', async () => {
    await expect(
      observeExternalCall('test_provider', 'lookup', async () => 'ok'),
    ).resolves.toBe('ok');
    const metrics = renderPrometheusMetrics();
    expect(metrics).toContain(
      'hnw_operational_counters_total{event="external_test_provider_lookup_attempted"}',
    );
    expect(metrics).toContain(
      'hnw_operational_counters_total{event="external_test_provider_lookup_succeeded"}',
    );
    expect(metrics).toContain(
      'hnw_operational_counters_total{event="external_test_provider_lookup_duration_ms_total"}',
    );
  });

  it('records failed external calls without swallowing the error', async () => {
    await expect(
      observeExternalCall('test_provider', 'failure', async () => {
        throw new Error('provider unavailable');
      }),
    ).rejects.toThrow('provider unavailable');
    expect(renderPrometheusMetrics()).toContain(
      'hnw_operational_counters_total{event="external_test_provider_failure_failed"}',
    );
  });
});
