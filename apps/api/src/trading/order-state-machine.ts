export type OrderState =
  'PENDING' | 'OPEN' | 'PARTIALLY_FILLED' | 'FILLED' | 'CANCELLED' | 'REJECTED';

const ALLOWED_TRANSITIONS: Readonly<Record<OrderState, readonly OrderState[]>> =
  {
    PENDING: ['OPEN', 'FILLED', 'REJECTED'],
    OPEN: ['PARTIALLY_FILLED', 'FILLED', 'CANCELLED'],
    PARTIALLY_FILLED: ['PARTIALLY_FILLED', 'FILLED', 'CANCELLED'],
    FILLED: [],
    CANCELLED: [],
    REJECTED: [],
  };

export class InvalidOrderTransitionError extends Error {
  constructor(current: OrderState, next: OrderState) {
    super(`Invalid order status transition: ${current} -> ${next}`);
    this.name = 'InvalidOrderTransitionError';
  }
}

export function assertOrderTransition(
  current: OrderState,
  next: OrderState,
): void {
  if (!ALLOWED_TRANSITIONS[current].includes(next)) {
    throw new InvalidOrderTransitionError(current, next);
  }
}
