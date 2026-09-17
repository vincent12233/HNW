const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', 'postgres']);

export class UnsafeFundingDatabaseUrlError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UnsafeFundingDatabaseUrlError';
  }
}

/** Never read process.env.DATABASE_URL. Integration tests must opt into a local test DB. */
export function requireFundingIntegrationDatabaseUrl(): string {
  const raw = process.env.FUNDING_INTEGRATION_DATABASE_URL?.trim();
  if (!raw) {
    throw new Error(
      'FUNDING_INTEGRATION_DATABASE_URL is required. Example: postgresql://hnw_test:PASSWORD@127.0.0.1:55432/hnw_funding_integration?schema=public. Do not use production DATABASE_URL.',
    );
  }
  return assertSafeFundingIntegrationDatabaseUrl(raw);
}

export function assertSafeFundingIntegrationDatabaseUrl(raw: string): string {
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    throw new UnsafeFundingDatabaseUrlError(
      'FUNDING_INTEGRATION_DATABASE_URL is not a valid URL',
    );
  }

  if (parsed.protocol !== 'postgres:' && parsed.protocol !== 'postgresql:') {
    throw new UnsafeFundingDatabaseUrlError(
      'FUNDING_INTEGRATION_DATABASE_URL must use the postgres protocol',
    );
  }

  const host = parsed.hostname.trim().toLowerCase();
  if (!LOCAL_HOSTS.has(host)) {
    throw new UnsafeFundingDatabaseUrlError(
      `Refusing host "${parsed.hostname}". Allowed: localhost, 127.0.0.1, postgres`,
    );
  }

  const database = decodeURIComponent(parsed.pathname.replace(/^\//, '')).split(
    '/',
  )[0];
  if (!/(test|e2e|integration)/i.test(database)) {
    throw new UnsafeFundingDatabaseUrlError(
      `Refusing database "${database}". Name must contain test, e2e, or integration`,
    );
  }

  return raw;
}

export function fundingRaceRuns(defaultRuns = 20): number {
  const parsed = Number(process.env.FUNDING_INTEGRATION_RACE_RUNS);
  if (Number.isInteger(parsed) && parsed >= 1 && parsed <= 50) {
    return parsed;
  }
  return defaultRuns;
}
