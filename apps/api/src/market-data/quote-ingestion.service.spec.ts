import { QuoteIngestionService } from './quote-ingestion.service';

describe('QuoteIngestionService', () => {
  it('persists stock quotes, records health and broadcasts them', async () => {
    const prisma = {
      instrument: {
        findUnique: jest.fn().mockResolvedValue({ id: 'instrument-1' }),
      },
      marketQuote: {
        upsert: jest.fn(),
      },
    } as any;
    const gateway = { emitQuoteUpdate: jest.fn() } as any;
    const health = { recordQuote: jest.fn() } as any;
    const service = new QuoteIngestionService(prisma, gateway, health);
    const updatedAt = new Date('2026-08-11T12:00:00Z');

    await service.ingest(
      'NSE',
      {
        symbol: 'RELIANCE',
        price: '100',
        previousClose: '98',
        openPrice: '99',
        highPrice: '101',
        lowPrice: '97',
        bidPrice: '99.9',
        askPrice: '100.1',
        volume: '1234',
        change: 2.04,
        source: 'YAHOO',
        updatedAt,
      },
      'STOCK',
    );

    expect(prisma.marketQuote.upsert).toHaveBeenCalled();
    expect(health.recordQuote).toHaveBeenCalledWith('YAHOO', updatedAt);
    expect(gateway.emitQuoteUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'STOCK',
        symbol: 'RELIANCE',
        exchange: 'NSE',
        source: 'YAHOO',
      }),
    );
  });

  it('broadcasts index quotes without requiring an instrument row', async () => {
    const prisma = {} as any;
    const gateway = { emitQuoteUpdate: jest.fn() } as any;
    const health = { recordQuote: jest.fn() } as any;
    const service = new QuoteIngestionService(prisma, gateway, health);
    const updatedAt = new Date();

    await service.ingest(
      'NSE',
      {
        symbol: 'NIFTY50',
        price: '25000',
        previousClose: '24900',
        openPrice: null,
        highPrice: null,
        lowPrice: null,
        bidPrice: null,
        askPrice: null,
        volume: '0',
        change: 0.4,
        source: 'YAHOO',
        updatedAt,
      },
      'INDEX',
    );

    expect(health.recordQuote).toHaveBeenCalledWith('YAHOO', updatedAt);
    expect(gateway.emitQuoteUpdate).toHaveBeenCalled();
  });
});
