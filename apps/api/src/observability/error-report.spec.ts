import { buildErrorReport, redactSensitiveText } from './error-report';

describe('privacy-safe error reports', () => {
  it('redacts credentials, PII, user directories, and encoded payloads', () => {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature';
    const encoded = 'A'.repeat(200);
    const source = [
      'Bearer top-secret-token',
      `id_token=${jwt}`,
      'person@example.com',
      '+91 98765 43210',
      'C:\\Users\\private-user\\project',
      encoded,
    ].join(' ');
    const result = redactSensitiveText(source);
    expect(result).not.toContain('top-secret-token');
    expect(result).not.toContain(jwt);
    expect(result).not.toContain('person@example.com');
    expect(result).not.toContain('98765');
    expect(result).not.toContain('private-user');
    expect(result).not.toContain(encoded);
    expect(result).toContain('[REDACTED]');
  });

  it('creates a stable fingerprint while omitting client-error stacks', () => {
    const error = new Error('Lookup failed for person@example.com');
    error.stack =
      'Error: token=private-token\n at C:\\Users\\private-user\\app.ts:1:1';
    const context = {
      requestId: 'request-id',
      method: 'GET',
      path: '/users/person@example.com',
      statusCode: 500,
    };
    const first = buildErrorReport(error, context);
    const second = buildErrorReport(error, context);
    expect(first.fingerprint).toBe(second.fingerprint);
    expect(JSON.stringify(first)).not.toContain('private-token');
    expect(JSON.stringify(first)).not.toContain('person@example.com');
    expect(JSON.stringify(first)).not.toContain('private-user');
    expect(first.stack).toBeDefined();
    expect(
      buildErrorReport(error, { ...context, statusCode: 400 }),
    ).not.toHaveProperty('stack');
  });
});
