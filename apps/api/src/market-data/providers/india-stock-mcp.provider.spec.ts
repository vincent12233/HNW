import { IndiaStockMcpProvider } from './india-stock-mcp.provider';

describe('IndiaStockMcpProvider', () => {
  const provider = new IndiaStockMcpProvider({ get: jest.fn() } as any);

  it('normalizes index aliases expected by india-stock-mcp', () => {
    expect((provider as any).normalizeSymbol('NIFTY50', 'NSE')).toBe('NIFTY 50');
    expect((provider as any).normalizeSymbol('BANKNIFTY', 'NSE')).toBe(
      'NIFTY BANK',
    );
    expect((provider as any).normalizeSymbol('RELIANCE.NS', 'NSE')).toBe(
      'RELIANCE',
    );
    expect((provider as any).isIndexSymbol('NIFTY50')).toBe(true);
    expect((provider as any).isIndexSymbol('SENSEX')).toBe(true);
    expect((provider as any).isIndexSymbol('RELIANCE')).toBe(false);
  });

  it('normalizes get_quote payload into MarketQuoteResult', () => {
    const quote = (provider as any).toQuote(
      {
        source: 'Yahoo Finance',
        symbol: 'RELIANCE.NS',
        price: 1266,
        change: 3,
        changePct: 0.24,
        open: 1260,
        dayHigh: 1274,
        dayLow: 1252,
        volume: 6107188,
      },
      'RELIANCE',
    );

    expect(quote).toEqual(
      expect.objectContaining({
        symbol: 'RELIANCE',
        price: '1266',
        previousClose: '1263',
        openPrice: '1260',
        highPrice: '1274',
        lowPrice: '1252',
        volume: '6107188',
        change: 0.24,
        source: 'INDIA_STOCK_MCP',
      }),
    );
    expect(quote.updatedAt).toBeInstanceOf(Date);
  });

  it('normalizes get_index payload into MarketQuoteResult', () => {
    const quote = (provider as any).toQuote(
      {
        index: 'NIFTY 50',
        last: 24500,
        variation: 120,
        percentChange: 0.49,
        previousClose: 24380,
        open: 24420,
        high: 24550,
        low: 24390,
      },
      'NIFTY50',
    );

    expect(quote).toEqual(
      expect.objectContaining({
        symbol: 'NIFTY50',
        price: '24500',
        previousClose: '24380',
        openPrice: '24420',
        highPrice: '24550',
        lowPrice: '24390',
        change: 0.49,
        source: 'INDIA_STOCK_MCP',
      }),
    );
  });

  it('surfaces MCP text errors cleanly', () => {
    expect(() =>
      (provider as any).parsePayload([
        { type: 'text', text: "Error: No quote found for 'UNKNOWN'" },
      ]),
    ).toThrow("No quote found for 'UNKNOWN'");
  });
});
