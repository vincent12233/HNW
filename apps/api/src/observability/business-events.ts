import { normalizeRateLimitPath } from '../common/rate-limit-store';

const failureEvents: Record<string, string> = {
  'POST /auth/login': 'auth_login_rejected',
  'POST /auth/register': 'auth_register_rejected',
  'POST /auth/refresh': 'auth_refresh_rejected',
  'POST /kyc/submit': 'kyc_submit_rejected',
  'POST /orders': 'order_submit_rejected',
  'POST /withdrawal/request': 'withdrawal_request_rejected',
};

export function businessFailureEvent(
  method: string,
  path: string,
  status: number,
) {
  if (status < 400) return null;
  return (
    failureEvents[`${method.toUpperCase()} ${normalizeRateLimitPath(path)}`] ??
    null
  );
}
