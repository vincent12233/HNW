import {
  observeExternalCall,
  recordJourneyMetric,
  renderPrometheusMetrics,
} from './metrics';

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

  it('publishes bounded journey histograms for SLO calculations', () => {
    recordJourneyMetric('order_submit', 240, true);
    recordJourneyMetric('order_submit', 620, false);

    const metrics = renderPrometheusMetrics();
    expect(metrics).toContain(
      'hnw_journey_duration_ms_bucket{journey="order_submit",le="250"}',
    );
    expect(metrics).toContain(
      'hnw_journey_duration_ms_count{journey="order_submit"} 2',
    );
    expect(metrics).toContain(
      'hnw_journey_errors_total{journey="order_submit"} 1',
    );
  });

  it('rejects arbitrary labels that could contain customer identifiers', () => {
    expect(() =>
      recordJourneyMetric('phone_919999999999' as 'order_submit', 10, true),
    ).toThrow('Unsupported journey metric');
    expect(renderPrometheusMetrics()).not.toContain('919999999999');
  });
});
