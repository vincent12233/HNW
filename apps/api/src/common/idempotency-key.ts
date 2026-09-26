import { BadRequestException } from '@nestjs/common';

const IDEMPOTENCY_KEY_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{7,99}$/;

export function optionalIdempotencyKey(value?: string) {
  const normalized = value?.trim();
  if (!normalized) return undefined;
  if (!IDEMPOTENCY_KEY_PATTERN.test(normalized)) {
    throw new BadRequestException({
      code: 'INVALID_IDEMPOTENCY_KEY',
      message:
        'Idempotency-Key must be 8-100 characters using letters, numbers, dot, underscore, colon or hyphen',
    });
  }
  return normalized;
}
