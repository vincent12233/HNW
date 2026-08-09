import { Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

import { MarketDataGateway } from './websocket/market-data/market-data.gateway';
@Injectable()
export class MarketDataService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: MarketDataGateway,
  ) {}

  /**
   * 获取当前行情
   */
  async getMarketSnapshot() {
    const instruments = await this.prisma.instrument.findMany({
      where: {
        isActive: true,
      },

      include: {
        quote: true,
      },

      orderBy: {
        displayOrder: 'asc',
      },
    });

    return instruments.map((item) => {
      const lastPrice = Number(item.quote?.lastPrice ?? 0);
      const previousClose = Number(item.quote?.previousClose ?? 0);
      const change =
        previousClose > 0 ? ((lastPrice - previousClose) / previousClose) * 100 : 0;

      return {
        symbol: item.symbol,

        exchange: item.exchange,

        name: item.name,

        logoUrl: item.logoUrl,

        category: item.category,

        displayOrder: item.displayOrder,

        price: item.quote?.lastPrice ?? null,

        change,

        previousClose: item.quote?.previousClose ?? null,

        bid: item.quote?.bidPrice ?? null,

        ask: item.quote?.askPrice ?? null,

        volume: item.quote?.volume?.toString() ?? '0',

        updatedAt: item.quote?.asOf ?? null,
      };
    });
  }

  /**
   * 更新股票实时价格
   */
  async updateQuote(symbol: string, price: string, volume?: string) {
    const instrument = await this.prisma.instrument.findFirst({
      where: {
        symbol,
      },
    });

    if (!instrument) {
      throw new NotFoundException('Instrument not found');
    }

    const quote = await this.prisma.marketQuote.update({
      where: {
        instrumentId: instrument.id,
      },

      data: {
        lastPrice: price,

        ...(volume
          ? {
              volume: BigInt(volume),
            }
          : {}),

        source: 'LIVE',

        asOf: new Date(),
      },
    });

    const update = {
      symbol,

      price: Number(quote.lastPrice),

      volume: quote.volume.toString(),

      updatedAt: quote.asOf,
    };

    this.gateway.emitQuoteUpdate(update);

    return update;
  }
}
