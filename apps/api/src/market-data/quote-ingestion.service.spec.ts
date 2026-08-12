import { QuoteIngestionService } from './quote-ingestion.service';

describe('QuoteIngestionService', () => {
  it('persists stock quotes, records health and broadcasts client-safe payloads', async () => {
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
        source: 'INDIA_STOCK_MCP',
        updatedAt,
      },
      'STOCK',
    );

    expect(prisma.marketQuote.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        update: expect.objectContaining({ source: 'INDIA_STOCK_MCP' }),
      }),
    );
    expect(health.recordQuote).toHaveBeenCalledWith(
      'INDIA_STOCK_MCP',
      updatedAt,
    );
    expect(gateway.emitQuoteUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'STOCK',
        symbol: 'RELIANCE',
        exchange: 'NSE',
        price: 100,
      }),
    );
    const payload = gateway.emitQuoteUpdate.mock.calls[0][0];
    expect(payload).not.toHaveProperty('source');
  });

  it('broadcasts and retains index quotes without exposing backend source metadata', async () => {
    const prisma = {} as any;
    const gateway = { emitQuoteUpdate: jest.fn() } as any;
    const health = { recordQuote: jest.fn() } as any;
    const service = new QuoteIngestionService(prisma, gateway, health);
    const updatedAt = new Date('2026-08-12T06:10:00Z');

    await service.ingest(
      'NSE',
      {
        symbol: 'NIFTY50',
        price: '25000',
        previousClose: '24900',
        openPrice: '24950',
        highPrice: '25020',
        lowPrice: '24880',
        bidPrice: null,
        askPrice: null,
        volume: '0',
        change: 0.4,
        source: 'INDIA_STOCK_MCP',
        updatedAt,
      },
      'INDEX',
    );

    expect(health.recordQuote).toHaveBeenCalledWith(
      'INDIA_STOCK_MCP',
      updatedAt,
    );
    expect(gateway.emitQuoteUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'INDEX',
        symbol: 'NIFTY50',
        exchange: 'NSE',
        price: 25000,
        change: 0.4,
      }),
    );

    const snapshot = service.getIndexSnapshot();
    expect(snapshot).toHaveLength(1);
    expect(snapshot[0]).toEqual(
      expect.objectContaining({
        type: 'INDEX',
        symbol: 'NIFTY50',
        exchange: 'NSE',
        price: 25000,
        updatedAt,
      }),
    );
    expect(snapshot[0]).not.toHaveProperty('source');
  });
});
