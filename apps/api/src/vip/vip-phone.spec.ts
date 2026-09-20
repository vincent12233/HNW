import { maskPhone } from './vip-phone';

describe('VIP phone masking', () => {
  it('never returns a complete phone number', () => {
    expect(maskPhone('+91 98765 43210')).toBe('******3210');
    expect(maskPhone('12')).toBe('****');
    expect(maskPhone(null)).toBeNull();
  });
});
