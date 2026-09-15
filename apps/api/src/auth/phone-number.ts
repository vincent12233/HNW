import { parsePhoneNumberFromString } from 'libphonenumber-js/max';

export function normalizePhone(value: string): string | null {
  if (typeof value !== 'string' || !/^[+\d\s().-]+$/.test(value)) return null;
  const input = value.trim();
  const digits = input.replace(/\D/g, '');
  // Preserve existing Indian account keys; international accounts use E.164.
  const parsed = parsePhoneNumberFromString(
    !input.startsWith('+') && /^91[6-9]\d{9}$/.test(digits)
      ? `+${digits}`
      : input,
    'IN',
  );
  if (!parsed?.isValid()) return null;
  return parsed.country === 'IN' ? parsed.nationalNumber : parsed.number;
}

export function internationalPhone(phone: string): string {
  return phone.startsWith('+') ? phone : `+91${phone}`;
}
