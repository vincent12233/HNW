export function resolveTrustProxyHops() {
  const rawValue = process.env.TRUST_PROXY_HOPS?.trim();
  if (!rawValue) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('TRUST_PROXY_HOPS must be set explicitly in production');
    }
    return 0;
  }
  const hops = Number(rawValue);
  if (!Number.isInteger(hops) || hops < 0 || hops > 5) {
    throw new Error('TRUST_PROXY_HOPS must be an integer from 0 to 5');
  }
  return hops;
}
