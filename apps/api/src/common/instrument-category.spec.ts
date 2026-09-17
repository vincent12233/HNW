import {
  isSpecialProductCategory,
  isStandardMarketInstrument,
  normalizeInstrumentCategory,
  ordinaryMarketCategoryWhere,
  SPECIAL_PRODUCT_CATEGORIES,
} from './instrument-category';

describe('instrument category policy', () => {
  it('normalizes with trim and case-insensitive matching', () => {
    expect(normalizeInstrumentCategory(' ipo ')).toBe('IPO');
    expect(isSpecialProductCategory('ipo')).toBe(true);
    expect(isSpecialProductCategory('IPO')).toBe(true);
    expect(isSpecialProductCategory('IpO')).toBe(true);
    expect(isSpecialProductCategory(' OTC ')).toBe(true);
    expect(isSpecialProductCategory('inst')).toBe(true);
    expect(isSpecialProductCategory('Institutional')).toBe(true);
  });

  it('does not treat empty, EQUITY, ETF or sector names as special products', () => {
    expect(isSpecialProductCategory(null)).toBe(false);
    expect(isSpecialProductCategory(undefined)).toBe(false);
    expect(isSpecialProductCategory('')).toBe(false);
    expect(isSpecialProductCategory('   ')).toBe(false);
    expect(isSpecialProductCategory('EQUITY')).toBe(false);
    expect(isSpecialProductCategory('ETF')).toBe(false);
    expect(isSpecialProductCategory('BEES')).toBe(false);
    expect(isSpecialProductCategory('IT')).toBe(false);
    expect(isSpecialProductCategory('IPO INDUSTRIES')).toBe(false);
    expect(isStandardMarketInstrument({ category: null })).toBe(true);
    expect(isStandardMarketInstrument({ category: 'EQUITY' })).toBe(true);
    expect(isStandardMarketInstrument({ category: 'ETF' })).toBe(true);
  });

  it('covers the actual protected aliases used by product writers', () => {
    expect([...SPECIAL_PRODUCT_CATEGORIES].sort()).toEqual(
      [
        'BLOCK',
        'BLOCK_TRADE',
        'INST',
        'INSTITUTIONAL',
        'IPO',
        'LIMIT_UP',
        'OTC',
      ].sort(),
    );
    expect(isSpecialProductCategory('LIMIT_UP')).toBe(true);
    expect(isSpecialProductCategory('BLOCK')).toBe(true);
    expect(isSpecialProductCategory('BLOCK_TRADE')).toBe(true);
    expect(isStandardMarketInstrument({ category: 'IPO' })).toBe(false);
  });

  it('builds a Prisma where-clause that keeps null categories and excludes exact specials', () => {
    const where = ordinaryMarketCategoryWhere();
    expect(where.OR).toEqual(
      expect.arrayContaining([
        { category: null },
        expect.objectContaining({
          NOT: {
            OR: expect.arrayContaining([
              {
                category: { equals: 'IPO', mode: 'insensitive' },
              },
              {
                category: { equals: 'OTC', mode: 'insensitive' },
              },
              {
                category: { equals: 'INSTITUTIONAL', mode: 'insensitive' },
              },
              {
                category: { equals: 'INST', mode: 'insensitive' },
              },
            ]),
          },
        }),
      ]),
    );
  });
});
