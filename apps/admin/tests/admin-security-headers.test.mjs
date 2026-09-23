import assert from 'node:assert/strict';
import test from 'node:test';

process.env.NODE_ENV = 'production';
process.env.NEXT_PUBLIC_API_URL = 'https://api.example.com';

const { default: nextConfig } = await import('../next.config.ts');

test('production admin headers protect the app and allow inline KYC PDF previews', async () => {
  const routes = await nextConfig.headers();
  const headers = new Map(routes[0].headers.map(({ key, value }) => [key, value]));
  const csp = headers.get('Content-Security-Policy');

  assert.match(csp, /connect-src 'self' https:\/\/api\.example\.com/);
  assert.match(csp, /frame-src 'self' data: blob:/);
  assert.match(csp, /frame-ancestors 'none'/);
  assert.match(csp, /object-src 'none'/);
  assert.equal(headers.get('Strict-Transport-Security'), 'max-age=63072000; includeSubDomains; preload');
  assert.equal(headers.get('X-Frame-Options'), 'DENY');
  assert.equal(headers.get('Cross-Origin-Opener-Policy'), 'same-origin');
});
