import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';

import { YahooProvider } from './providers/yahoo.provider';

import { MarketDataGateway } from './websocket/market-data/market-data.gateway';

@Injectable()
export class NseSyncService {
  private readonly logger = new Logger(NseSyncService.name);

  private readonly symbols = ['RELIANCE', 'TCS', 'HDFCBANK'];

  private readonly indices = ['NIFTY50', 'SENSEX', 'BANKNIFTY'];

  constructor(
    private readonly prisma: PrismaService,

    private readonly yahooProvider: YahooProvider,

    private readonly marketDataGateway: MarketDataGateway,
  ) {}

  @Cron('*/30 * * * * *')
  async sync() {
    this.logger.log('Updating market quotes...');

    await this.syncStocks();

    await this.syncIndices();
  }

  private async syncStocks() {
    for (const symbol of this.symbols) {
      try {
        const quote = await this.yahooProvider.getQuote(symbol);

        const instrument = await this.prisma.instrument.findFirst({
          where: {
            symbol,
            exchange: 'NSE',
          },
        });

        if (!instrument) {
          this.logger.warn(`${symbol} instrument not found`);

          continue;
        }

        const now = new Date();

        await this.prisma.marketQuote.update({
          where: {
            instrumentId: instrument.id,
          },

          data: {
            lastPrice: quote.price,

            previousClose: quote.previousClose,

            ...(quote.openPrice !== null
              ? {
                  openPrice: quote.openPrice,
                }
              : {}),

            ...(quote.highPrice !== null
              ? {
                  highPrice: quote.highPrice,
                }
              : {}),

            ...(quote.lowPrice !== null
              ? {
                  lowPrice: quote.lowPrice,
                }
              : {}),

            bidPrice: quote.price,

            askPrice: quote.price,

            volume: BigInt(quote.volume || 0),

            source: 'MARKET',

            asOf: now,
          },
        });

        this.logger.log(
          `${symbol} updated ${quote.price} change ${quote.change.toFixed(2)}%`,
        );

        this.marketDataGateway.emitQuoteUpdate({
          type: 'STOCK',

          symbol,

          price: Number(quote.price),

          change: quote.change,

          volume: quote.volume,

          previousClose: Number(quote.previousClose),

          openPrice: quote.openPrice !== null ? Number(quote.openPrice) : null,

          highPrice: quote.highPrice !== null ? Number(quote.highPrice) : null,

          lowPrice: quote.lowPrice !== null ? Number(quote.lowPrice) : null,

          updatedAt: now,
        });
      } catch (error) {
        this.logger.error(`${symbol} update failed`);
      }
    }
  }

  private async syncIndices() {
    for (const symbol of this.indices) {
      try {
        const quote = await this.yahooProvider.getQuote(symbol);

        const now = new Date();

        this.logger.log(
          `${symbol} index updated ${quote.price} change ${quote.change.toFixed(2)}%`,
        );

        this.marketDataGateway.emitQuoteUpdate({
          type: 'INDEX',

          symbol,

          price: Number(quote.price),

          change: quote.change,

          previousClose: Number(quote.previousClose),

          openPrice: quote.openPrice !== null ? Number(quote.openPrice) : null,

          highPrice: quote.highPrice !== null ? Number(quote.highPrice) : null,

          lowPrice: quote.lowPrice !== null ? Number(quote.lowPrice) : null,

          volume: quote.volume,

          updatedAt: now,
        });
      } catch (error) {
        this.logger.error(`${symbol} index update failed`);
      }
    }
  }
}
