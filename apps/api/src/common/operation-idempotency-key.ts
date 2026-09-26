import { BadRequestException } from '@nestjs/common';
import { BUSINESS_ERROR_CODES } from './business-error-codes';
import { optionalIdempotencyKey } from './idempotency-key';

export function assertOperationIdempotencyKey(
  value: string | undefined,
  expected: string,
) {
  const key = optionalIdempotencyKey(value);
  if (key && key !== expected) {
    throw new BadRequestException({
      code: BUSINESS_ERROR_CODES.IDEMPOTENCY_KEY_REUSED,
      message: 'Idempotency-Key does not match this operation',
    });
  }
  return key ?? expected;
}
