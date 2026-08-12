import { MarketDataProviderService } from './market-data-provider.service';

describe('MarketDataProviderService', () => {
  it('uses India Stock MCP by default', async () => {
    const indiaStockMcp = {
      name: 'INDIA_STOCK_MCP',
      getQuote: jest.fn().mockResolvedValue({ symbol: 'RELIANCE' }),
    } as any;
    const yahoo = { name: 'YAHOO', getQuote: jest.fn() } as any;
    const config = { get: jest.fn().mockReturnValue(undefined) } as any;
    const service = new MarketDataProviderService(
      config,
      indiaStockMcp,
      yahoo,
    );

    expect(service.providerName).toBe('INDIA_STOCK_MCP');
    await service.getQuote('RELIANCE', 'NSE');
    expect(indiaStockMcp.getQuote).toHaveBeenCalledWith('RELIANCE', 'NSE');
  });

  it('keeps Yahoo available as an explicit provider', () => {
    const indiaStockMcp = { name: 'INDIA_STOCK_MCP' } as any;
    const yahoo = { name: 'YAHOO' } as any;
    const config = { get: jest.fn().mockReturnValue('YAHOO') } as any;
    const service = new MarketDataProviderService(
      config,
      indiaStockMcp,
      yahoo,
    );

    expect(service.providerName).toBe('YAHOO');
  });

  it('rejects an unsupported configured provider', () => {
    const indiaStockMcp = { name: 'INDIA_STOCK_MCP' } as any;
    const yahoo = { name: 'YAHOO' } as any;
    const config = { get: jest.fn().mockReturnValue('UNKNOWN') } as any;
    const service = new MarketDataProviderService(
      config,
      indiaStockMcp,
      yahoo,
    );

    expect(() => service.providerName).toThrow(
      'Unsupported market data provider: UNKNOWN',
    );
  });
});
