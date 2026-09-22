import {
  assertSafeFundingIntegrationDatabaseUrl,
  UnsafeFundingDatabaseUrlError,
} from '../funding-integration/database-url.guard';

describe('funding integration database URL guard', () => {
  it('accepts local integration database names', () => {
    expect(
      assertSafeFundingIntegrationDatabaseUrl(
        'postgresql://hnw_test:secret@127.0.0.1:55432/hnw_funding_integration?schema=public',
      ),
    ).toContain('hnw_funding_integration');
    expect(
      assertSafeFundingIntegrationDatabaseUrl(
        'postgresql://hnw_test:secret@localhost/hnw_e2e',
      ),
    ).toContain('hnw_e2e');
    expect(
      assertSafeFundingIntegrationDatabaseUrl(
        'postgresql://hnw_test:secret@postgres:5432/hnw_test',
      ),
    ).toContain('hnw_test');
  });

  it('rejects production-like hosts and database names', () => {
    expect(() =>
      assertSafeFundingIntegrationDatabaseUrl(
        'postgresql://user:pass@db.prod.example.com:5432/hnw_funding_integration',
      ),
    ).toThrow(UnsafeFundingDatabaseUrlError);
    expect(() =>
      assertSafeFundingIntegrationDatabaseUrl(
        'postgresql://hnw_test:secret@127.0.0.1:5432/hnw_production',
      ),
    ).toThrow(UnsafeFundingDatabaseUrlError);
  });
});
