import { businessFailureEvent } from './business-events';

describe('business failure event classification', () => {
  it.each([
    ['/auth/login', 'auth_login_rejected'],
    ['/auth/register', 'auth_register_rejected'],
    ['/auth/refresh', 'auth_refresh_rejected'],
    ['/kyc/submit', 'kyc_submit_rejected'],
    ['/orders', 'order_submit_rejected'],
    ['/withdrawal/request', 'withdrawal_request_rejected'],
  ])('identifies POST %s without logging request data', (path, event) => {
    expect(businessFailureEvent('POST', path, 400)).toBe(event);
    expect(businessFailureEvent('POST', path, 500)).toBe(event);
    expect(businessFailureEvent('POST', path, 201)).toBeNull();
    expect(businessFailureEvent('GET', path, 400)).toBeNull();
  });

  it('does not turn arbitrary routes into metric labels', () => {
    expect(
      businessFailureEvent('POST', '/orders/private-customer-id', 400),
    ).toBeNull();
  });
});
