import { assertOperationIdempotencyKey } from './operation-idempotency-key';

describe('assertOperationIdempotencyKey', () => {
  it('uses the deterministic operation key when the header is absent', () => {
    expect(
      assertOperationIdempotencyKey(undefined, 'DEPOSIT:123:APPROVE'),
    ).toBe('DEPOSIT:123:APPROVE');
  });

  it('accepts only the matching operation key', () => {
    expect(
      assertOperationIdempotencyKey(
        'DEPOSIT:123:APPROVE',
        'DEPOSIT:123:APPROVE',
      ),
    ).toBe('DEPOSIT:123:APPROVE');
    expect(() =>
      assertOperationIdempotencyKey(
        'DEPOSIT:123:REJECT',
        'DEPOSIT:123:APPROVE',
      ),
    ).toThrow('Idempotency-Key does not match this operation');
  });
});
