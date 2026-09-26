import { currentRequestId, runWithRequestContext } from './request-context';

describe('request context', () => {
  it('keeps the request id across awaited work without leaking it', async () => {
    expect(currentRequestId()).toBeUndefined();
    await runWithRequestContext('request-1', async () => {
      await Promise.resolve();
      expect(currentRequestId()).toBe('request-1');
    });
    expect(currentRequestId()).toBeUndefined();
  });
});
