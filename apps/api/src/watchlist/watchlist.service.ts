import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Exchange, InstrumentType } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

type WatchlistRow = {
  symbol: string;
  exchange: string;
  createdAt: Date;
};

@Injectable()
export class WatchlistService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string) {
    return this.prisma.$queryRaw<WatchlistRow[]>`
      SELECT i."symbol", i."exchange"::text AS "exchange", w."createdAt"
      FROM "user_watchlist_items" w
      INNER JOIN "instruments" i ON i."id" = w."instrumentId"
      WHERE w."userId" = ${userId}
        AND i."isActive" = true
        AND i."type" = ${InstrumentType.EQUITY}::"InstrumentType"
        AND i."exchange" IN (${Exchange.NSE}::"Exchange", ${Exchange.BSE}::"Exchange")
      ORDER BY w."createdAt" DESC
    `;
  }

  async add(userId: string, symbol: string, exchange: Exchange = Exchange.NSE) {
    const normalizedSymbol = symbol.trim().toUpperCase();
    if (!normalizedSymbol) {
      throw new BadRequestException('Symbol is required');
    }

    const instrument = await this.prisma.instrument.findFirst({
      where: {
        symbol: normalizedSymbol,
        exchange,
        type: InstrumentType.EQUITY,
        isActive: true,
      },
      select: { id: true, symbol: true, exchange: true },
    });

    if (!instrument) {
      throw new NotFoundException('Stock not found');
    }

    await this.prisma.$executeRaw`
      INSERT INTO "user_watchlist_items" ("id", "userId", "instrumentId")
      VALUES (${randomUUID()}, ${userId}, ${instrument.id})
      ON CONFLICT ("userId", "instrumentId") DO NOTHING
    `;

    return {
      symbol: instrument.symbol,
      exchange: instrument.exchange,
      watched: true,
    };
  }

  async remove(
    userId: string,
    symbol: string,
    exchange: Exchange = Exchange.NSE,
  ) {
    const normalizedSymbol = symbol.trim().toUpperCase();
    const instrument = await this.prisma.instrument.findFirst({
      where: {
        symbol: normalizedSymbol,
        exchange,
        type: InstrumentType.EQUITY,
      },
      select: { id: true },
    });

    if (instrument) {
      await this.prisma.$executeRaw`
        DELETE FROM "user_watchlist_items"
        WHERE "userId" = ${userId}
          AND "instrumentId" = ${instrument.id}
      `;
    }

    return { symbol: normalizedSymbol, exchange, watched: false };
  }
}
