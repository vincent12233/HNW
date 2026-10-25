import {
  assertOrderTransition,
  InvalidOrderTransitionError,
} from './order-state-machine';

describe('assertOrderTransition', () => {
  it.each([
    ['PENDING', 'OPEN'],
    ['PENDING', 'FILLED'],
    ['PENDING', 'REJECTED'],
    ['OPEN', 'PARTIALLY_FILLED'],
    ['OPEN', 'FILLED'],
    ['OPEN', 'CANCELLED'],
    ['PARTIALLY_FILLED', 'PARTIALLY_FILLED'],
    ['PARTIALLY_FILLED', 'FILLED'],
    ['PARTIALLY_FILLED', 'CANCELLED'],
  ] as const)('allows %s -> %s', (current, next) => {
    expect(() => assertOrderTransition(current, next)).not.toThrow();
  });

  it.each([
    ['FILLED', 'CANCELLED'],
    ['CANCELLED', 'FILLED'],
    ['REJECTED', 'OPEN'],
    ['OPEN', 'PENDING'],
  ] as const)('rejects %s -> %s', (current, next) => {
    expect(() => assertOrderTransition(current, next)).toThrow(
      InvalidOrderTransitionError,
    );
  });
});
