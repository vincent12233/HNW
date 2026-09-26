import { BUSINESS_ERROR_CODES } from './business-error-codes';

describe('business error code catalog', () => {
  it('keeps stable codes for money, approval, and authorization flows', () => {
    expect(BUSINESS_ERROR_CODES).toMatchObject({
      WITHDRAWAL_ALREADY_REVIEWED: 'WITHDRAWAL_ALREADY_REVIEWED',
      IDEMPOTENCY_KEY_REUSED: 'IDEMPOTENCY_KEY_REUSED',
      ORDER_IDEMPOTENCY_CONFLICT: 'ORDER_IDEMPOTENCY_CONFLICT',
      FUNDS_INSUFFICIENT: 'FUNDS_INSUFFICIENT',
      APPROVAL_INVALID_STATE: 'APPROVAL_INVALID_STATE',
      KYC_REQUIRED: 'KYC_REQUIRED',
    });
  });
});
