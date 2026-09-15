import { MarketDataProviderService } from './market-data-provider.service';

describe('MarketDataProviderService', () => {
  it('uses Yahoo by default to avoid MCP zip-extraction dependency', async () => {
    const indiaStockMcp = {
      name: 'INDIA_STOCK_MCP',
      getQuote: jest.fn().mockResolvedValue({ symbol: 'RELIANCE' }),
    } as any;
    const yahoo = {
      name: 'YAHOO',
      getQuote: jest.fn().mockResolvedValue({ symbol: 'RELIANCE' }),
    } as any;
    const config = { get: jest.fn().mockReturnValue(undefined) } as any;
    const service = new MarketDataProviderService(config, indiaStockMcp, yahoo);

    expect(service.providerName).toBe('YAHOO');
    await service.getQuote('RELIANCE', 'NSE');
    expect(yahoo.getQuote).toHaveBeenCalledWith('RELIANCE', 'NSE');
  });

  it('keeps India Stock MCP available as an explicit provider', () => {
    const indiaStockMcp = { name: 'INDIA_STOCK_MCP' } as any;
    const yahoo = { name: 'YAHOO' } as any;
    const config = { get: jest.fn().mockReturnValue('INDIA_STOCK_MCP') } as any;
    const service = new MarketDataProviderService(config, indiaStockMcp, yahoo);

    expect(service.providerName).toBe('INDIA_STOCK_MCP');
  });

  it('rejects an unsupported configured provider', () => {
    const indiaStockMcp = { name: 'INDIA_STOCK_MCP' } as any;
    const yahoo = { name: 'YAHOO' } as any;
    const config = { get: jest.fn().mockReturnValue('UNKNOWN') } as any;
    const service = new MarketDataProviderService(config, indiaStockMcp, yahoo);

    expect(() => service.providerName).toThrow(
      'Unsupported market data provider: UNKNOWN',
    );
  });
});
