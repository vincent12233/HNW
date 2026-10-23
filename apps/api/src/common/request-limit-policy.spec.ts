import { requestLimit } from './request-limit-policy';

describe('request limit policy', () => {
  it('keeps existing protected business route limits unchanged', () => {
    expect(requestLimit('/auth/login')).toBe(10);
    expect(requestLimit('/auth/refresh')).toBe(20);
    expect(requestLimit('/kyc/submit')).toBe(10);
    expect(requestLimit('/otc/orders')).toBe(10);
    expect(requestLimit('/withdrawal/request')).toBe(30);
    expect(requestLimit('/orders')).toBe(60);
    expect(requestLimit('/market')).toBe(300);
  });

  it('limits anonymous client error ingestion separately from ordinary reads', () => {
    expect(requestLimit('/observability/client-errors')).toBe(30);
  });
});
