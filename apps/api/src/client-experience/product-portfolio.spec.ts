import { productCategory, summarizeProducts } from './product-portfolio';

const position = (category: string, quantity = 2, price: number | null = 15) => ({
  id: category, quantity, frozenQuantity: 1, averagePrice: 10, realizedPnl: 3,
  instrument: { symbol: category, name: category, exchange: 'NSE', category, quote: price === null ? null : { lastPrice: price } },
});
describe('Product portfolio valuation', () => {
  it('excludes ordinary shares including lookalike category names', () => {
    expect(productCategory('IPO_BANK')).toBeNull();
    expect(productCategory(' inst ')).toBe('Institutional');
    const summary = summarizeProducts([position('IT'), position('IPO'), position('OTC'), position('INST')]);
    expect(summary.currentValue).toBe(90);
    expect(summary.positionCount).toBe(3);
    expect(summary.categories.reduce((sum, item) => sum + item.allocationPercent, 0)).toBeCloseTo(100);
    expect(summary.totalPnl).toBe(39);
  });
  it('uses cost with an explicit valuation source if quote is absent or zero', () => {
    const result = summarizeProducts([position('IPO', 2, null), position('OTC', 2, 0)]);
    expect(result.currentValue).toBe(40);
    expect(result.unrealizedPnl).toBe(0);
    expect(result.categories[2].positions[0]).toMatchObject({ valuationSource: 'COST', availableQuantity: 1 });
  });
  it('retains realized returns for closed products without a fake allocation', () => {
    const result = summarizeProducts([position('IPO', 0)]);
    expect(result.totalPnl).toBe(3);
    expect(result.positionCount).toBe(0);
    expect(result.bestSegment).toBeNull();
    expect(result.categories.every(group => group.allocationPercent === 0)).toBe(true);
  });
});
