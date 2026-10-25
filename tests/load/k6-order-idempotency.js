import http from 'k6/http';
import { check, fail } from 'k6';

const baseUrl = __ENV.BASE_URL || 'http://localhost:3000';
const orderPath = __ENV.ORDER_PATH || '/api/orders';

export const options = {
  vus: 5,
  iterations: 10,
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1000'],
    checks: ['rate>0.99'],
  },
};

export function setup() {
  if (__ENV.K6_ALLOW_ORDER_WRITES !== 'isolated-disposable') {
    fail('Order load test requires K6_ALLOW_ORDER_WRITES=isolated-disposable');
  }
  if (!__ENV.AUTH_TOKEN || !__ENV.TEST_SYMBOL) {
    fail('AUTH_TOKEN and TEST_SYMBOL are required for the isolated test account');
  }
}

export default function () {
  const clientOrderId = `k6-idempotency-${__VU}-${__ITER}`;
  const body = JSON.stringify({
    symbol: __ENV.TEST_SYMBOL,
    side: __ENV.TEST_SIDE || 'BUY',
    orderType: __ENV.TEST_ORDER_TYPE || 'LIMIT',
    quantity: Number(__ENV.TEST_QUANTITY || '1'),
    price: Number(__ENV.TEST_PRICE || '1'),
    clientOrderId,
  });
  const params = {
    headers: {
      Authorization: `Bearer ${__ENV.AUTH_TOKEN}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': clientOrderId,
    },
    tags: { journey: 'order_submit' },
  };
  const first = http.post(`${baseUrl}${orderPath}`, body, params);
  const duplicate = http.post(`${baseUrl}${orderPath}`, body, params);
  check(first, { 'initial order accepted or deterministically rejected': (r) => r.status < 500 });
  check(duplicate, {
    'duplicate never creates a server error': (r) => r.status < 500,
    'duplicate returns the same identity when accepted': (r) =>
      first.status >= 400 || r.status >= 400 || first.json('id') === r.json('id'),
  });
}
