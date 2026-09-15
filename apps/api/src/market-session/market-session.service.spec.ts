import { MarketSessionService } from './market-session.service';

describe('MarketSessionService', () => {
  function createService(values: Record<string, string | undefined> = {}) {
    const config = {
      get: jest.fn((key: string) => values[key]),
    } as any;
    return new MarketSessionService(config);
  }

  it('opens at 09:15 IST and closes at 15:30 IST on a weekday', () => {
    const service = createService();

    expect(
      service.isNormalMarketOpen(new Date('2026-08-12T03:44:59.000Z')),
    ).toBe(false);
    expect(
      service.isNormalMarketOpen(new Date('2026-08-12T03:45:00.000Z')),
    ).toBe(true);
    expect(
      service.isNormalMarketOpen(new Date('2026-08-12T09:59:59.000Z')),
    ).toBe(true);
    expect(
      service.isNormalMarketOpen(new Date('2026-08-12T10:00:00.000Z')),
    ).toBe(false);
  });

  it('stays closed on weekends', () => {
    const service = createService();

    expect(
      service.isNormalMarketOpen(new Date('2026-08-15T05:00:00.000Z')),
    ).toBe(false);
    expect(
      service.isNormalMarketOpen(new Date('2026-08-16T05:00:00.000Z')),
    ).toBe(false);
  });

  it('stays closed on an official 2026 NSE capital-market holiday', () => {
    const service = createService();

    expect(service.isTradingDay(new Date('2026-01-15T05:00:00.000Z'))).toBe(
      false,
    );
    expect(
      service.isNormalMarketOpen(new Date('2026-01-15T05:00:00.000Z')),
    ).toBe(false);
  });

  it('adds configured exchange holidays to the built-in calendar', () => {
    const service = createService({ MARKET_HOLIDAYS_IST: '2026-08-12' });

    expect(service.isTradingDay(new Date('2026-08-12T05:00:00.000Z'))).toBe(
      false,
    );
    expect(
      service.isNormalMarketOpen(new Date('2026-08-12T05:00:00.000Z')),
    ).toBe(false);
  });

  it('expires a DAY order at 15:30 IST on its placement date', () => {
    const service = createService();
    const placedAt = new Date('2026-08-12T05:00:00.000Z');

    expect(
      service.isDayOrderExpired(placedAt, new Date('2026-08-12T09:59:59.000Z')),
    ).toBe(false);
    expect(
      service.isDayOrderExpired(placedAt, new Date('2026-08-12T10:00:00.000Z')),
    ).toBe(true);
  });

  it('expires a DAY order left active into a later date', () => {
    const service = createService();
    const placedAt = new Date('2026-08-12T05:00:00.000Z');

    expect(
      service.isDayOrderExpired(placedAt, new Date('2026-08-13T03:00:00.000Z')),
    ).toBe(true);
  });

  it('returns client-safe session status without market-data source details', () => {
    const service = createService();
    const at = new Date('2026-08-12T05:00:00.000Z');

    expect(service.getStatus(at)).toEqual({
      isOpen: true,
      isTradingDay: true,
      timezone: 'Asia/Kolkata',
      openTime: '09:15',
      closeTime: '15:30',
      asOf: at,
    });
  });
});
