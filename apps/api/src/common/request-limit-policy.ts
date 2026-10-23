export function requestLimit(path: string): number {
  if (
    path === '/auth/login' ||
    path === '/auth/google' ||
    path === '/auth/biometric' ||
    path.startsWith('/auth/recovery')
  ) {
    return 10;
  }
  if (path.startsWith('/auth/')) return 20;
  if (path === '/observability/client-errors') return 30;
  if (path.startsWith('/kyc/')) return 10;
  if (path === '/otc/orders') return 10;
  if (
    path.includes('/deposit') ||
    path.includes('/withdrawal') ||
    path.includes('/loans') ||
    (path.includes('/accounts/') &&
      (path.includes('/credit') || path.includes('/debit')))
  ) {
    return 30;
  }
  if (path.includes('/orders') || path.includes('/withdrawal')) return 60;
  return 300;
}
