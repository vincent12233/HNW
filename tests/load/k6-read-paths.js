import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = __ENV.BASE_URL || 'http://localhost:3000';
const marketPath = __ENV.MARKET_SNAPSHOT_PATH || '/api/market/stocks';

export const options = {
  scenarios: {
    steady_reads: { executor: 'constant-vus', vus: 20, duration: '2m' },
    market_open_burst: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 200,
      stages: [
        { target: 100, duration: '30s' },
        { target: 100, duration: '60s' },
        { target: 10, duration: '30s' },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    checks: ['rate>0.99'],
  },
};

export default function () {
  const health = http.get(`${baseUrl}/health/ready`, { tags: { journey: 'health' } });
  check(health, { 'ready response is successful': (r) => r.status === 200 });
  const market = http.get(`${baseUrl}${marketPath}`, { tags: { journey: 'market_read' } });
  check(market, { 'market read is not a server error': (r) => r.status < 500 });
  sleep(0.2);
}
