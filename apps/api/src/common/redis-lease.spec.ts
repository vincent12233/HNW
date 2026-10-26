import { RedisLease } from './redis-lease';

describe('RedisLease', () => {
  it('acquires with NX/PX and releases using the exact owner token', async () => {
    const client = {
      set: jest.fn().mockResolvedValue('OK'),
      eval: jest.fn().mockResolvedValue(1),
    };
    const lease = await new RedisLease(client as never).acquire(
      'matching',
      5000,
      'api-a',
    );

    expect(lease).not.toBeNull();
    expect(client.set).toHaveBeenCalledWith(
      'hnw:lease:matching',
      expect.stringMatching(/^api-a:/),
      { NX: true, PX: 5000 },
    );
    await expect(lease!.release()).resolves.toBe(true);
    expect(client.eval.mock.calls[0][1].arguments).toEqual([lease!.token]);
  });

  it('does not claim a resource already held by another instance', async () => {
    const client = { set: jest.fn().mockResolvedValue(null), eval: jest.fn() };
    await expect(
      new RedisLease(client as never).acquire('matching', 5000, 'api-b'),
    ).resolves.toBeNull();
    expect(client.eval).not.toHaveBeenCalled();
  });

  it('reports false when a stale owner cannot release the renewed lease', async () => {
    const client = {
      set: jest.fn().mockResolvedValue('OK'),
      eval: jest.fn().mockResolvedValue(0),
    };
    const lease = await new RedisLease(client as never).acquire(
      'expiry',
      5000,
      'old-api',
    );
    await expect(lease!.release()).resolves.toBe(false);
  });
});
