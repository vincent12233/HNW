import { MarketDataProviderService } from './market-data-provider.service';

describe('MarketDataProviderService', () => {
  it('uses Yahoo by default as the temporary development provider', async () => {
    const yahoo = {
      name: 'YAHOO',
      getQuote: jest.fn().mockResolvedValue({ symbol: 'RELIANCE' }),
      getHistory: jest.fn(),
    } as any;
    const config = { get: jest.fn().mockReturnValue(undefined) } as any;
    const service = new MarketDataProviderService(config, yahoo);

    expect(service.providerName).toBe('YAHOO');
    await service.getQuote('RELIANCE', 'NSE');
    expect(yahoo.getQuote).toHaveBeenCalledWith('RELIANCE', 'NSE');
  });

  it('rejects unsupported configured providers', () => {
    const yahoo = { name: 'YAHOO', getQuote: jest.fn(), getHistory: jest.fn() } as any;
    const config = { get: jest.fn().mockReturnValue('INDIA_STOCK_MCP') } as any;
    const service = new MarketDataProviderService(config, yahoo);

    expect(() => service.providerName).toThrow(
      'Unsupported market data provider: INDIA_STOCK_MCP',
    );
  });

  it('rejects an unknown configured provider', () => {
    const yahoo = { name: 'YAHOO', getQuote: jest.fn(), getHistory: jest.fn() } as any;
    const config = { get: jest.fn().mockReturnValue('UNKNOWN') } as any;
    const service = new MarketDataProviderService(config, yahoo);

    expect(() => service.providerName).toThrow(
      'Unsupported market data provider: UNKNOWN',
    );
  });
});
