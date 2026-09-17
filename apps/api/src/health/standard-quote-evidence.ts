import { Exchange, InstrumentType } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { ordinaryMarketCategoryWhere } from '../common/instrument-category';

export const standardMarketInstrumentWhere = () => ({
  isActive: true,
  exchange: { in: [Exchange.NSE, Exchange.BSE] },
  type: InstrumentType.EQUITY,
  AND: [ordinaryMarketCategoryWhere()],
});

export async function loadStandardQuoteEvidence(prisma: PrismaService) {
  const instrumentWhere = standardMarketInstrumentWhere();

  const [latest, activeCount, quotedCount] = await Promise.all([
    prisma.marketQuote.findFirst({
      where: {
        lastPrice: { gt: 0 },
        instrument: instrumentWhere,
      },
      orderBy: { asOf: 'desc' },
      select: { asOf: true },
    }),
    prisma.instrument.count({ where: instrumentWhere }),
    prisma.instrument.count({
      where: {
        ...instrumentWhere,
        quote: { is: { lastPrice: { gt: 0 } } },
      },
    }),
  ]);

  return {
    latestAsOf: latest?.asOf ?? null,
    activeCount,
    quotedCount,
  };
}
