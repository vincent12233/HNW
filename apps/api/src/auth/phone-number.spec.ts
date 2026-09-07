import { normalizePhone } from './phone-number';
describe('International account phone numbers', () => {
  it.each(['9876543210', '919876543210', '+919876543210'])('keeps the existing Indian key for %s', input => expect(normalizePhone(input)).toBe('9876543210'));
  it.each(['+12025550123', '+447911123456', '+8613812345678'])('preserves %s', input => expect(normalizePhone(input)).toBe(input));
  it.each(['not a phone', '+999123456789', '123', '+0000000000'])('rejects %s', input => expect(normalizePhone(input)).toBeNull());
});
