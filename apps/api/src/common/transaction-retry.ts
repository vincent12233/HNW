export interface TransactionRetryOptions {
  maxAttempts?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
  random?: () => number;
  sleep?: (delayMs: number) => Promise<void>;
  isRetryable?: (error: unknown) => boolean;
  onExhausted?: (error: unknown) => unknown;
}

const hasPrismaCode = (error: unknown, expectedCode: string): boolean =>
  typeof error === 'object' &&
  error !== null &&
  'code' in error &&
  (error as { code?: unknown }).code === expectedCode;

const defaultSleep = (delayMs: number) =>
  new Promise<void>((resolve) => setTimeout(resolve, delayMs));

/**
 * Runs a serializable transaction operation with a small, bounded retry budget.
 * The operation owns the actual database transaction so this helper remains
 * reusable without weakening service-specific error handling.
 */
export async function runSerializableTransaction<T>(
  operation: (attempt: number) => Promise<T>,
  options: TransactionRetryOptions = {},
): Promise<T> {
  const maxAttempts = Math.max(1, Math.min(options.maxAttempts ?? 3, 5));
  const baseDelayMs = Math.max(0, options.baseDelayMs ?? 15);
  const maxDelayMs = Math.max(baseDelayMs, options.maxDelayMs ?? 150);
  const random = options.random ?? Math.random;
  const sleep = options.sleep ?? defaultSleep;
  const isRetryable =
    options.isRetryable ?? ((error: unknown) => hasPrismaCode(error, 'P2034'));

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await operation(attempt);
    } catch (error: unknown) {
      if (!isRetryable(error)) throw error;
      if (attempt === maxAttempts) {
        throw options.onExhausted?.(error) ?? error;
      }

      const exponentialDelay = baseDelayMs * 2 ** (attempt - 1);
      const jitteredDelay = exponentialDelay * (1 + random());
      await sleep(Math.min(maxDelayMs, Math.round(jitteredDelay)));
    }
  }

  throw new Error('Serializable transaction retry invariant violated');
}
