import { runSerializableTransaction } from './transaction-retry';

describe('runSerializableTransaction', () => {
  it('retries transient serialization failures with bounded jitter', async () => {
    const operation = jest
      .fn<Promise<string>, [number]>()
      .mockRejectedValueOnce({ code: 'P2034' })
      .mockRejectedValueOnce({ code: 'P2034' })
      .mockResolvedValue('committed');
    const sleep = jest.fn().mockResolvedValue(undefined);

    await expect(
      runSerializableTransaction(operation, {
        maxAttempts: 3,
        baseDelayMs: 10,
        random: () => 0.5,
        sleep,
      }),
    ).resolves.toBe('committed');

    expect(operation).toHaveBeenCalledTimes(3);
    expect(operation.mock.calls.map(([attempt]) => attempt)).toEqual([1, 2, 3]);
    expect(sleep).toHaveBeenNthCalledWith(1, 15);
    expect(sleep).toHaveBeenNthCalledWith(2, 30);
  });

  it('does not retry non-transient database or business failures', async () => {
    const duplicate = { code: 'P2002' };
    const operation = jest.fn().mockRejectedValue(duplicate);

    await expect(runSerializableTransaction(operation)).rejects.toBe(duplicate);
    expect(operation).toHaveBeenCalledTimes(1);
  });

  it('maps the final serialization failure after the strict attempt limit', async () => {
    const exhausted = new Error('safe conflict');
    const operation = jest.fn().mockRejectedValue({ code: 'P2034' });

    await expect(
      runSerializableTransaction(operation, {
        maxAttempts: 2,
        baseDelayMs: 0,
        onExhausted: () => exhausted,
      }),
    ).rejects.toBe(exhausted);
    expect(operation).toHaveBeenCalledTimes(2);
  });
});
