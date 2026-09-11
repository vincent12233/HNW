export const productCategories = ['Institutional', 'OTC', 'IPO'] as const;
export function productCategory(value: string | null): typeof productCategories[number] | null {
  switch ((value ?? '').trim().toUpperCase()) {
    case 'INST': case 'INSTITUTIONAL': case 'LIMIT_UP': return 'Institutional';
    case 'OTC': case 'BLOCK': case 'BLOCK_TRADE': return 'OTC';
    case 'IPO': return 'IPO';
    default: return null;
  }
}

type PositionInput = {
  id: string; quantity: number; frozenQuantity: number;
  averagePrice: unknown; realizedPnl: unknown;
  instrument: { symbol: string; name: string; exchange: string; category: string | null; quote: { lastPrice: unknown } | null };
};

export function summarizeProducts(positions: PositionInput[]) {
  const groups = productCategories.map(category => ({ category, invested: 0, currentValue: 0, realizedPnl: 0, unrealizedPnl: 0, positions: [] as {
    id: string; symbol: string; name: string; exchange: string; quantity: number; availableQuantity: number;
    averagePrice: number; currentPrice: number; currentValue: number; unrealizedPnl: number; valuationSource: string;
  }[] }));
  for (const position of positions) {
    const category = productCategory(position.instrument.category);
    if (!category) continue;
    const group = groups.find(item => item.category === category)!;
    group.realizedPnl += Number(position.realizedPnl);
    if (position.quantity <= 0) continue;
    const averagePrice = Number(position.averagePrice);
    const quote = Number(position.instrument.quote?.lastPrice);
    const hasQuote = Number.isFinite(quote) && quote > 0;
    const currentPrice = hasQuote ? quote : averagePrice;
    const invested = position.quantity * averagePrice;
    const currentValue = position.quantity * currentPrice;
    const unrealizedPnl = currentValue - invested;
    group.invested += invested;
    group.currentValue += currentValue;
    group.unrealizedPnl += unrealizedPnl;
    group.positions.push({ id: position.id, symbol: position.instrument.symbol, name: position.instrument.name,
      exchange: position.instrument.exchange, quantity: position.quantity,
      availableQuantity: Math.max(0, position.quantity - position.frozenQuantity), averagePrice, currentPrice,
      currentValue, unrealizedPnl, valuationSource: hasQuote ? 'MARKET' : 'COST' });
  }
  const currentValue = groups.reduce((sum, group) => sum + group.currentValue, 0);
  const invested = groups.reduce((sum, group) => sum + group.invested, 0);
  const realizedPnl = groups.reduce((sum, group) => sum + group.realizedPnl, 0);
  const unrealizedPnl = groups.reduce((sum, group) => sum + group.unrealizedPnl, 0);
  const categories = groups.map(group => ({ ...group, allocationPercent: currentValue > 0 ? group.currentValue / currentValue * 100 : 0,
    totalPnl: group.realizedPnl + group.unrealizedPnl,
    unrealizedReturnPercent: group.invested > 0 ? group.unrealizedPnl / group.invested * 100 : null }));
  const ranked = categories.filter(group => group.invested > 0).sort((a, b) => b.unrealizedReturnPercent! - a.unrealizedReturnPercent!);
  return { currentValue, invested, realizedPnl, unrealizedPnl, totalPnl: realizedPnl + unrealizedPnl,
    positionCount: groups.reduce((sum, group) => sum + group.positions.length, 0),
    bestSegment: ranked[0]?.category ?? null, categories };
}
