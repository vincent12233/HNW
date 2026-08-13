import { TrueDataProvider } from './truedata.provider';

describe('TrueDataProvider', () => {
  it('stages symbols, connects transport and normalizes ticks', async () => {
    const symbols = {
      toProviderSymbol: jest.fn((symbol: string) => symbol),
    } as any;
    const normalizer = {
      fromArray: jest.fn().mockReturnValue({
        symbol: 'RELIANCE',
        exchange: 'NSE',
        price: '100',
        previousClose: '99',
        openPrice: null,
        highPrice: null,
        lowPrice: null,
        bidPrice: null,
        askPrice: null,
        volume: '1',
        change: 1.01,
        source: 'TRUEDATA',
        updatedAt: new Date(),
      }),
    } as any;
    const subscriptionPolicy = {
      validateAndBatch: jest.fn((items: string[]) => ({
        symbols: items,
        batches: [items],
      })),
    } as any;
    let tickHandler: ((values: unknown[]) => void) | undefined;
    const transport = {
      connect: jest.fn((_items: string[], handler: (values: unknown[]) => void) => {
        tickHandler = handler;
      }),
      disconnect: jest.fn(),
      subscribe: jest.fn(),
      isConnected: jest.fn().mockReturnValue(true),
    } as any;
    const provider = new TrueDataProvider(
      symbols,
      normalizer,
      subscriptionPolicy,
      transport,
    );
    const quotes: any[] = [];
    provider.onQuote((quote) => quotes.push(quote));

    await provider.subscribe([{ symbol: 'RELIANCE', exchange: 'NSE' }]);
    await provider.connect();
    tickHandler?.(['RELIANCE']);

    expect(transport.connect).toHaveBeenCalledWith(
      ['RELIANCE'],
      expect.any(Function),
    );
    expect(normalizer.fromArray).toHaveBeenCalledWith(['RELIANCE'], 'NSE');
    expect(quotes).toHaveLength(1);
    expect(provider.isConnected).toBe(true);
  });

  it('preserves BSE exchange from the staged subscription', async () => {
    const symbols = {
      toProviderSymbol: jest.fn((symbol: string) => symbol),
    } as any;
    const normalizer = {
      fromArray: jest.fn().mockReturnValue({
        symbol: 'ABC',
        exchange: 'BSE',
      }),
    } as any;
    const subscriptionPolicy = {
      validateAndBatch: jest.fn((items: string[]) => ({
        symbols: items,
        batches: [items],
      })),
    } as any;
    let tickHandler: ((values: unknown[]) => void) | undefined;
    const transport = {
      connect: jest.fn((_items: string[], handler: (values: unknown[]) => void) => {
        tickHandler = handler;
      }),
      disconnect: jest.fn(),
      subscribe: jest.fn(),
      isConnected: jest.fn().mockReturnValue(true),
    } as any;
    const provider = new TrueDataProvider(
      symbols,
      normalizer,
      subscriptionPolicy,
      transport,
    );
    provider.onQuote(() => undefined);

    await provider.subscribe([{ symbol: 'ABC', exchange: 'BSE' }]);
    await provider.connect();
    tickHandler?.(['ABC']);

    expect(normalizer.fromArray).toHaveBeenCalledWith(['ABC'], 'BSE');
  });

  it('dynamically subscribes only newly added symbols after connect', async () => {
    const symbols = {
      toProviderSymbol: jest.fn((symbol: string) => symbol),
    } as any;
    const normalizer = { fromArray: jest.fn() } as any;
    const subscriptionPolicy = {
      validateAndBatch: jest.fn((items: string[]) => ({
        symbols: [...new Set(items)],
        batches: items.length ? [items] : [],
      })),
    } as any;
    const transport = {
      connect: jest.fn(),
      disconnect: jest.fn(),
      subscribe: jest.fn(),
      isConnected: jest.fn().mockReturnValue(true),
    } as any;
    const provider = new TrueDataProvider(
      symbols,
      normalizer,
      subscriptionPolicy,
      transport,
    );

    await provider.subscribe([{ symbol: 'RELIANCE', exchange: 'NSE' }]);
    await provider.connect();
    await provider.subscribe([
      { symbol: 'RELIANCE', exchange: 'NSE' },
      { symbol: 'TCS', exchange: 'NSE' },
    ]);

    expect(transport.subscribe).toHaveBeenCalledWith(['TCS']);
  });
});
