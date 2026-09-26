import { BadRequestException } from '@nestjs/common';
import { optionalIdempotencyKey } from './idempotency-key';

describe('optionalIdempotencyKey', () => {
  it('accepts normalized client request identifiers', () => {
    expect(optionalIdempotencyKey(' app:withdrawal:1234 ')).toBe(
      'app:withdrawal:1234',
    );
  });

  it('allows omitted keys for backwards compatibility', () => {
    expect(optionalIdempotencyKey(undefined)).toBeUndefined();
  });

  it('rejects malformed keys with a stable business code', () => {
    expect(() => optionalIdempotencyKey('bad key')).toThrow(
      BadRequestException,
    );
    try {
      optionalIdempotencyKey('bad key');
    } catch (error) {
      expect((error as BadRequestException).getResponse()).toMatchObject({
        code: 'INVALID_IDEMPOTENCY_KEY',
      });
    }
  });
});
