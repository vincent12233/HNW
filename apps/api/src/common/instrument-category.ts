import { Prisma } from '../generated/prisma/client';

/**
 * Special-product categories stored on Instrument.category.
 * Values come from existing IPO / OTC / Institutional (and alias) writers.
 * Sector strings such as "IPO INDUSTRIES" are not in this set.
 */
export const SPECIAL_PRODUCT_CATEGORIES = [
  'INST',
  'INSTITUTIONAL',
  'LIMIT_UP',
  'OTC',
  'BLOCK',
  'BLOCK_TRADE',
  'IPO',
] as const;

export type SpecialProductCategory =
  (typeof SPECIAL_PRODUCT_CATEGORIES)[number];

export function normalizeInstrumentCategory(
  category: string | null | undefined,
): string {
  return (category ?? '').trim().toUpperCase();
}

export function isSpecialProductCategory(
  category: string | null | undefined,
): boolean {
  const normalized = normalizeInstrumentCategory(category);
  if (!normalized) {
    return false;
  }
  return (SPECIAL_PRODUCT_CATEGORIES as readonly string[]).includes(normalized);
}

export function isStandardMarketInstrument(instrument: {
  category?: string | null;
}): boolean {
  return !isSpecialProductCategory(instrument.category);
}

/** Prisma filter: ordinary Home / Markets / search must exclude special products. */
export function ordinaryMarketCategoryWhere(): Prisma.InstrumentWhereInput {
  return {
    OR: [
      { category: null },
      {
        NOT: {
          OR: SPECIAL_PRODUCT_CATEGORIES.map((category) => ({
            category: {
              equals: category,
              mode: 'insensitive' as const,
            },
          })),
        },
      },
    ],
  };
}
