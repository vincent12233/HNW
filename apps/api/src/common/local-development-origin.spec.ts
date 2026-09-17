import { isLocalDevelopmentOrigin } from './local-development-origin';

describe('development browser origin allowlist', () => {
  it.each([
    'http://localhost:3002',
    'https://localhost',
    'http://127.0.0.1:3000',
    'http://[::1]:3002',
    'http://10.20.30.40:3002',
    'http://192.168.1.100:3002',
    'http://172.16.0.1:3002',
    'https://172.31.255.254',
  ])('accepts the local origin %s', (origin) => {
    expect(isLocalDevelopmentOrigin(origin)).toBe(true);
  });

  it.each([
    'null',
    'not a URL',
    'ftp://localhost',
    'http://172.15.0.1:3002',
    'http://172.32.0.1:3002',
    'http://192.169.1.1:3002',
    'https://example.com',
    'https://localhost.example.com',
    'http://10.0.0.1.example.com',
    'http://10.256.1.1',
    'http://192.168.1',
    'http://172.16.1',
    'http://user:password@localhost:3002',
    'http://localhost:3002/path',
    'http://localhost:3002?key=value',
    'http://localhost:3002#fragment',
  ])('rejects non-local or malformed origin %s', (origin) => {
    expect(isLocalDevelopmentOrigin(origin)).toBe(false);
  });
});
