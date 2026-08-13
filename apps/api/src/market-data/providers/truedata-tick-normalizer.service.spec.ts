import { TrueDataSymbolMapperService } from './truedata-symbol-mapper.service';
import { TrueDataTickNormalizerService } from './truedata-tick-normalizer.service';

describe('TrueData adapters', () => {
  const symbols = new TrueDataSymbolMapperService();
  const normalizer = new TrueDataTickNormalizerService(symbols);

  it('maps internal index symbols to TrueData format', () => {
    expect(symbols.toProviderSymbol('NIFTY50', 'NSE')).toBe('NIFTY 50');
    expect(symbols.toProviderSymbol('BANKNIFTY', 'NSE')).toBe('NIFTY BANK');
    expect(symbols.toProviderSymbol('RELIANCE', 'NSE')).toBe('RELIANCE');
  });

  it('normalizes documented TrueData tick fields', () => {
    const quote = normalizer.fromArray([
      'NIFTY 50',
      '2026-08-11T10:15:00+05:30',
      25000,
      10,
      24990,
      123456,
      24950,
      25020,
      24920,
      24800,
      0,
      0,
      0,
      '',
      1,
      24999,
      50,
      25001,
      40,
    ]);

    expect(quote).toEqual(
      expect.objectContaining({
        symbol: 'NIFTY50',
        exchange: 'NSE',
        price: '25000',
        previousClose: '24800',
        bidPrice: '24999',
        askPrice: '25001',
        volume: '123456',
        source: 'TRUEDATA',
      }),
    );
  });
});
