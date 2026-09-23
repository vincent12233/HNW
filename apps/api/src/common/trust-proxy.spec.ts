describe('proxy trust configuration', () => {
  const originalNodeEnv = process.env.NODE_ENV;
  const originalTrustProxyHops = process.env.TRUST_PROXY_HOPS;

  afterEach(() => {
    process.env.NODE_ENV = originalNodeEnv;
    process.env.TRUST_PROXY_HOPS = originalTrustProxyHops;
  });

  it('does not trust forwarded addresses by default in development', async () => {
    process.env.NODE_ENV = 'development';
    delete process.env.TRUST_PROXY_HOPS;
    const { resolveTrustProxyHops } = await import('./trust-proxy');
    expect(resolveTrustProxyHops()).toBe(0);
  });

  it('requires an explicit bounded hop count in production', async () => {
    process.env.NODE_ENV = 'production';
    delete process.env.TRUST_PROXY_HOPS;
    const { resolveTrustProxyHops } = await import('./trust-proxy');
    expect(() => resolveTrustProxyHops()).toThrow(/must be set explicitly/);
    process.env.TRUST_PROXY_HOPS = '6';
    expect(() => resolveTrustProxyHops()).toThrow(/integer from 0 to 5/);
    process.env.TRUST_PROXY_HOPS = '1';
    expect(resolveTrustProxyHops()).toBe(1);
  });
});
