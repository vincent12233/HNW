import { MarketDataHealthService } from './market-data-health.service';

describe('MarketDataHealthService', () => {
  it('starts stale before any quote is received', () => {
    const config = { get: jest.fn().mockReturnValue('60000') } as any;
    const service = new MarketDataHealthService(config);

    expect(service.getStatus()).toEqual(
      expect.objectContaining({ healthy: false, stale: true, lastQuoteAt: null }),
    );
  });

  it('becomes healthy after a recent quote', () => {
    const config = { get: jest.fn().mockReturnValue('60000') } as any;
    const service = new MarketDataHealthService(config);
    const at = new Date();

    service.recordQuote('TRUEDATA', at);

    expect(service.getStatus()).toEqual(
      expect.objectContaining({
        healthy: true,
        stale: false,
        lastQuoteAt: at,
        lastSource: 'TRUEDATA',
      }),
    );
  });
});
