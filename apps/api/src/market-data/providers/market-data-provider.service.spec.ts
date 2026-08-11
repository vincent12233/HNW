import { MarketDataProviderService } from './market-data-provider.service';

describe('MarketDataProviderService', () => {
  it('uses Yahoo by default', async () => {
    const yahoo = {
      name: 'YAHOO',
      getQuote: jest.fn().mockResolvedValue({ symbol: 'RELIANCE' }),
    } as any;
    const config = { get: jest.fn().mockReturnValue(undefined) } as any;
    const service = new MarketDataProviderService(config, yahoo);

    expect(service.providerName).toBe('YAHOO');
    await service.getQuote('RELIANCE', 'NSE');
    expect(yahoo.getQuote).toHaveBeenCalledWith('RELIANCE', 'NSE');
  });

  it('rejects an unsupported configured provider', () => {
    const yahoo = { name: 'YAHOO' } as any;
    const config = { get: jest.fn().mockReturnValue('UNKNOWN') } as any;
    const service = new MarketDataProviderService(config, yahoo);

    expect(() => service.providerName).toThrow(
      'Unsupported market data provider: UNKNOWN',
    );
  });
});
