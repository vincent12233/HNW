import { MarketDataProviderService } from './market-data-provider.service';

function yahooStub() {
  return {
    name: 'YAHOO',
    getQuote: jest.fn().mockResolvedValue({ symbol: 'RELIANCE' }),
  } as any;
}

function mcpStub() {
  return {
    name: 'INDIA_STOCK_MCP',
    getQuote: jest.fn().mockResolvedValue({ symbol: 'RELIANCE' }),
  } as any;
}

function apifyStub(configured: boolean) {
  return {
    name: 'APIFY',
    isConfigured: () => configured,
    getQuote: jest.fn().mockResolvedValue({
      symbol: 'RELIANCE',
      source: 'APIFY',
    }),
  } as any;
}

describe('MarketDataProviderService', () => {
  it('defaults to APIFY and does not silently use Yahoo', async () => {
    const yahoo = yahooStub();
    const apify = apifyStub(true);
    const config = { get: jest.fn().mockReturnValue(undefined) } as any;
    const service = new MarketDataProviderService(
      config,
      mcpStub(),
      yahoo,
      apify,
    );

    expect(service.providerName).toBe('APIFY');
    expect(service.fallbackEnabled).toBe(false);
    await service.getQuote('RELIANCE', 'NSE');
    expect(apify.getQuote).toHaveBeenCalledWith('RELIANCE', 'NSE');
    expect(yahoo.getQuote).not.toHaveBeenCalled();
  });

  it('does not automatically fall back to Yahoo when APIFY is unconfigured', async () => {
    const yahoo = yahooStub();
    const apify = apifyStub(false);
    apify.getQuote.mockRejectedValue(
      new Error(
        'MARKET_DATA_PROVIDER=APIFY requires APIFY_TOKEN and APIFY_ACTOR_ID',
      ),
    );
    const config = {
      get: jest.fn((key: string) => {
        if (key === 'MARKET_DATA_FALLBACK_ENABLED') return 'false';
        return undefined;
      }),
    } as any;
    const service = new MarketDataProviderService(
      config,
      mcpStub(),
      yahoo,
      apify,
    );

    expect(service.providerName).toBe('APIFY');
    await expect(service.getQuote('RELIANCE', 'NSE')).rejects.toThrow(
      'APIFY_TOKEN and APIFY_ACTOR_ID',
    );
    expect(yahoo.getQuote).not.toHaveBeenCalled();
  });

  it('uses Yahoo only when explicitly selected', async () => {
    const yahoo = yahooStub();
    const config = { get: jest.fn().mockReturnValue('YAHOO') } as any;
    const service = new MarketDataProviderService(
      config,
      mcpStub(),
      yahoo,
      apifyStub(false),
    );

    expect(service.providerName).toBe('YAHOO');
    await service.getQuote('RELIANCE', 'NSE');
    expect(yahoo.getQuote).toHaveBeenCalledWith('RELIANCE', 'NSE');
  });

  it('keeps India Stock MCP available as an explicit provider', () => {
    const config = { get: jest.fn().mockReturnValue('INDIA_STOCK_MCP') } as any;
    const service = new MarketDataProviderService(
      config,
      mcpStub(),
      yahooStub(),
      apifyStub(false),
    );

    expect(service.providerName).toBe('INDIA_STOCK_MCP');
  });

  it('rejects an unsupported configured provider', () => {
    const config = { get: jest.fn().mockReturnValue('UNKNOWN') } as any;
    const service = new MarketDataProviderService(
      config,
      mcpStub(),
      yahooStub(),
      apifyStub(false),
    );

    expect(() => service.providerName).toThrow(
      'Unsupported market data provider: UNKNOWN',
    );
  });

  it('uses fallback provider only when explicitly enabled', async () => {
    const yahoo = yahooStub();
    const apify = apifyStub(false);
    const config = {
      get: jest.fn((key: string) => {
        if (key === 'MARKET_DATA_PROVIDER') return 'APIFY';
        if (key === 'MARKET_DATA_FALLBACK_ENABLED') return 'true';
        if (key === 'MARKET_DATA_FALLBACK_PROVIDER') return 'YAHOO';
        return undefined;
      }),
    } as any;
    const service = new MarketDataProviderService(
      config,
      mcpStub(),
      yahoo,
      apify,
    );

    expect(service.providerName).toBe('YAHOO');
    await service.getQuote('RELIANCE', 'BSE');
    expect(yahoo.getQuote).toHaveBeenCalledWith('RELIANCE', 'BSE');
  });
});
