import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Exchange, InstrumentType, Prisma } from '../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateInstrumentDto } from './dto/create-instrument.dto';
import { ListAdminInstrumentsQueryDto } from './dto/list-admin-instruments-query.dto';
import { ListInstrumentsQueryDto } from './dto/list-instruments-query.dto';
import { UpdateInstrumentStatusDto } from './dto/update-instrument-status.dto';
import { UpdateLiveQuoteDto } from './dto/update-live-quote.dto';
@Injectable()
export class MarketService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async listInstruments(query: ListInstrumentsQueryDto) {
    const search = query.search?.trim();

    const instruments = await this.prisma.instrument.findMany({
      where: {
        isActive: true,
        ...(query.exchange ? { exchange: query.exchange } : {}),
        ...(search
          ? {
              OR: [
                {
                  symbol: {
                    contains: search,
                    mode: 'insensitive',
                  },
                },
                {
                  name: {
                    contains: search,
                    mode: 'insensitive',
                  },
                },
              ],
            }
          : {}),
      },
      include: {
        quote: true,
      },
      orderBy: [
        { displayOrder: 'asc' },
        { exchange: 'asc' },
        { symbol: 'asc' },
      ],
    });

    return {
      total: instruments.length,
      data: instruments.map((instrument) => ({
        ...instrument,
        quote: instrument.quote
          ? {
              ...instrument.quote,
              volume: instrument.quote.volume.toString(),
            }
          : null,
      })),
    };
  }

  async listAdminInstruments(query: ListAdminInstrumentsQueryDto) {
    const search = query.search?.trim();
    const skip = (query.page - 1) * query.pageSize;

    const where = {
      ...(query.exchange
        ? {
            exchange: query.exchange,
          }
        : {}),
      ...(query.type
        ? {
            type: query.type,
          }
        : {}),
      ...(query.isActive !== undefined
        ? {
            isActive: query.isActive,
          }
        : {}),
      ...(search
        ? {
            OR: [
              {
                symbol: {
                  contains: search,
                  mode: 'insensitive' as const,
                },
              },
              {
                name: {
                  contains: search,
                  mode: 'insensitive' as const,
                },
              },
              {
                isin: {
                  contains: search,
                  mode: 'insensitive' as const,
                },
              },
            ],
          }
        : {}),
    };

    const [total, instruments] = await this.prisma.$transaction([
      this.prisma.instrument.count({
        where,
      }),
      this.prisma.instrument.findMany({
        where,
        include: {
          quote: true,
          _count: {
            select: {
              orders: true,
              trades: true,
              positions: true,
            },
          },
        },
        orderBy: [
          {
            displayOrder: 'asc',
          },
          {
            exchange: 'asc',
          },
          {
            symbol: 'asc',
          },
        ],
        skip,
        take: query.pageSize,
      }),
    ]);

    return {
      page: query.page,
      pageSize: query.pageSize,
      total,
      totalPages: Math.ceil(total / query.pageSize),
      filters: {
        search: search ?? null,
        exchange: query.exchange ?? null,
        type: query.type ?? null,
        isActive: query.isActive ?? null,
      },
      data: instruments.map((instrument) => ({
        ...instrument,
        quote: instrument.quote
          ? {
              ...instrument.quote,
              volume: instrument.quote.volume.toString(),
            }
          : null,
        statistics: {
          orderCount: instrument._count.orders,
          tradeCount: instrument._count.trades,
          positionCount: instrument._count.positions,
        },
        _count: undefined,
      })),
    };
  }

  async getAdminInstrument(instrumentId: string) {
    const instrument = await this.prisma.instrument.findUnique({
      where: {
        id: instrumentId,
      },
      include: {
        quote: true,
        _count: {
          select: {
            orders: true,
            trades: true,
            positions: true,
          },
        },
      },
    });

    if (!instrument) {
      throw new NotFoundException('Instrument not found');
    }

    return {
      ...instrument,
      quote: instrument.quote
        ? {
            ...instrument.quote,
            volume: instrument.quote.volume.toString(),
          }
        : null,
      statistics: {
        orderCount: instrument._count.orders,
        tradeCount: instrument._count.trades,
        positionCount: instrument._count.positions,
      },
      _count: undefined,
    };
  }

  async createInstrument(administratorId: string, dto: CreateInstrumentDto) {
    const symbol = dto.symbol.trim().toUpperCase();
    const name = dto.name.trim();
    const currency = dto.currency.trim().toUpperCase();
    const isin = dto.isin?.trim().toUpperCase() || null;
    const logoUrl = dto.logoUrl?.trim() || null;
    const category = dto.category?.trim() || null;

    const tickSize = new Prisma.Decimal(dto.tickSize);
    const lastPrice = new Prisma.Decimal(dto.lastPrice);
    const bidPrice = new Prisma.Decimal(dto.bidPrice ?? dto.lastPrice);
    const askPrice = new Prisma.Decimal(dto.askPrice ?? dto.lastPrice);

    if (bidPrice.greaterThan(askPrice)) {
      throw new BadRequestException(
        'bidPrice must be less than or equal to askPrice',
      );
    }

    const prices = [
      { name: 'lastPrice', value: lastPrice },
      { name: 'bidPrice', value: bidPrice },
      { name: 'askPrice', value: askPrice },
    ];

    for (const price of prices) {
      if (!price.value.mod(tickSize).equals(0)) {
        throw new BadRequestException(
          `${price.name} must follow tick size ${tickSize.toString()}`,
        );
      }
    }

    try {
      const created = await this.prisma.$transaction(
        async (tx) => {
          const existing = await tx.instrument.findUnique({
            where: {
              exchange_symbol: {
                exchange: dto.exchange,
                symbol,
              },
            },
            select: {
              id: true,
            },
          });

          if (existing) {
            throw new ConflictException(
              'Instrument already exists for this exchange and symbol',
            );
          }

          const instrument = await tx.instrument.create({
            data: {
              exchange: dto.exchange,
              symbol,
              name,
              isin,
              logoUrl,
              category,
              displayOrder: Number(dto.displayOrder ?? 0),
              type: dto.type,
              currency,
              lotSize: dto.lotSize,
              tickSize,
              isActive: true,
            },
          });

          const quote = await tx.marketQuote.create({
            data: {
              instrumentId: instrument.id,
              lastPrice,
              openPrice: lastPrice,
              highPrice: lastPrice,
              lowPrice: lastPrice,
              previousClose: lastPrice,
              bidPrice,
              askPrice,
              volume: BigInt(dto.volume),
              source: 'LIVE_FEED',
              asOf: new Date(),
            },
          });

          return {
            instrument,
            quote,
          };
        },
        {
          isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
        },
      );

      await this.auditService.createLog({
        actorId: administratorId,
        action: 'INSTRUMENT_CREATED',
        resource: 'INSTRUMENT',
        resourceId: created.instrument.id,
        description: `${created.instrument.exchange}:${created.instrument.symbol} created`,
        metadata: {
          exchange: created.instrument.exchange,
          symbol: created.instrument.symbol,
          name: created.instrument.name,
          isin: created.instrument.isin,
          type: created.instrument.type,
          currency: created.instrument.currency,
          lotSize: created.instrument.lotSize,
          tickSize: created.instrument.tickSize.toString(),
          lastPrice: created.quote.lastPrice.toString(),
        },
      });

      return {
        message: 'Instrument created successfully',
        instrument: {
          ...created.instrument,
          quote: {
            ...created.quote,
            volume: created.quote.volume.toString(),
          },
        },
      };
    } catch (error: unknown) {
      if (
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        (error as { code?: unknown }).code === 'P2002'
      ) {
        throw new ConflictException(
          'Instrument already exists or ISIN is already in use',
        );
      }

      throw error;
    }
  }

  async updateInstrumentStatus(
    administratorId: string,
    instrumentId: string,
    dto: UpdateInstrumentStatusDto,
  ) {
    const instrument = await this.prisma.instrument.findUnique({
      where: {
        id: instrumentId,
      },
      select: {
        id: true,
        exchange: true,
        symbol: true,
        name: true,
        isActive: true,
      },
    });

    if (!instrument) {
      throw new NotFoundException('Instrument not found');
    }

    const updatedInstrument = await this.prisma.instrument.update({
      where: {
        id: instrumentId,
      },
      data: {
        isActive: dto.isActive,
      },
      select: {
        id: true,
        exchange: true,
        symbol: true,
        name: true,
        isin: true,
        type: true,
        currency: true,
        lotSize: true,
        tickSize: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    await this.auditService.createLog({
      actorId: administratorId,
      action: dto.isActive ? 'INSTRUMENT_ACTIVATED' : 'INSTRUMENT_DEACTIVATED',
      resource: 'INSTRUMENT',
      resourceId: instrumentId,
      description: `${instrument.exchange}:${instrument.symbol} ${
        dto.isActive ? 'activated' : 'deactivated'
      }`,
      metadata: {
        exchange: instrument.exchange,
        symbol: instrument.symbol,
        name: instrument.name,
        previousIsActive: instrument.isActive,
        newIsActive: updatedInstrument.isActive,
      },
    });

    return {
      message: dto.isActive
        ? 'Instrument activated successfully'
        : 'Instrument deactivated successfully',
      previousIsActive: instrument.isActive,
      instrument: updatedInstrument,
    };
  }

  async getInstrument(exchange: Exchange, symbol: string) {
    const normalizedSymbol = symbol.trim().toUpperCase();

    const instrument = await this.prisma.instrument.findUnique({
      where: {
        exchange_symbol: {
          exchange,
          symbol: normalizedSymbol,
        },
      },
      include: {
        quote: true,
      },
    });

    if (!instrument || !instrument.isActive) {
      throw new NotFoundException('Instrument not found');
    }

    return {
      ...instrument,
      quote: instrument.quote
        ? {
            ...instrument.quote,
            volume: instrument.quote.volume.toString(),
          }
        : null,
    };
  }

  async getQuote(exchange: Exchange, symbol: string) {
    const normalizedSymbol = symbol.trim().toUpperCase();

    const instrument = await this.prisma.instrument.findUnique({
      where: {
        exchange_symbol: {
          exchange,
          symbol: normalizedSymbol,
        },
      },
      include: {
        quote: true,
      },
    });

    if (!instrument || !instrument.isActive) {
      throw new NotFoundException('Instrument not found');
    }

    if (!instrument.quote) {
      throw new NotFoundException('Market quote not found');
    }

    return {
      exchange: instrument.exchange,
      symbol: instrument.symbol,
      name: instrument.name,
      currency: instrument.currency,
      ...instrument.quote,
      volume: instrument.quote.volume.toString(),
    };
  }

  async updateLiveQuote(
    exchange: Exchange,
    symbol: string,
    dto: UpdateLiveQuoteDto,
  ) {
    const normalizedSymbol = symbol.trim().toUpperCase();

    const instrument = await this.prisma.instrument.findUnique({
      where: {
        exchange_symbol: {
          exchange,
          symbol: normalizedSymbol,
        },
      },
      include: {
        quote: true,
      },
    });

    if (!instrument || !instrument.isActive) {
      throw new NotFoundException('Instrument not found');
    }

    if (!instrument.quote) {
      throw new NotFoundException('Market quote not found');
    }

    const lastPrice = new Prisma.Decimal(dto.lastPrice);
    const bidPrice = new Prisma.Decimal(dto.bidPrice ?? dto.lastPrice);
    const askPrice = new Prisma.Decimal(dto.askPrice ?? dto.lastPrice);
    const asOf = new Date();

    const quote = await this.prisma.marketQuote.update({
      where: {
        instrumentId: instrument.id,
      },
      data: {
        lastPrice,
        bidPrice,
        askPrice,
        ...(dto.volume !== undefined
          ? {
              volume: BigInt(dto.volume),
            }
          : {}),
        source: 'LIVE_FEED',
        asOf,
      },
    });

    return {
      exchange: instrument.exchange,
      symbol: instrument.symbol,
      name: instrument.name,
      currency: instrument.currency,
      ...quote,
      volume: quote.volume.toString(),
    };
  }

  async seedLiveMarket() {
    const asOf = new Date();
    const instruments = [
      {
        symbol: 'RELIANCE',
        exchange: Exchange.NSE,
        name: 'Reliance Industries Limited',
        isin: 'INE002A01018',
        type: InstrumentType.EQUITY,
        lastPrice: '1432.50',
        openPrice: '1421.00',
        highPrice: '1440.00',
        lowPrice: '1415.25',
        previousClose: '1425.40',
        bidPrice: '1432.45',
        askPrice: '1432.55',
        volume: BigInt(12500000),
      },
      {
        symbol: 'TCS',
        exchange: Exchange.NSE,
        name: 'Tata Consultancy Services Limited',
        isin: 'INE467B01029',
        type: InstrumentType.EQUITY,
        lastPrice: '3215.75',
        openPrice: '3188.00',
        highPrice: '3230.50',
        lowPrice: '3180.25',
        previousClose: '3192.60',
        bidPrice: '3215.50',
        askPrice: '3216.00',
        volume: BigInt(3850000),
      },
      {
        symbol: 'HDFCBANK',
        exchange: Exchange.NSE,
        name: 'HDFC Bank Limited',
        isin: 'INE040A01034',
        type: InstrumentType.EQUITY,
        lastPrice: '985.20',
        openPrice: '978.50',
        highPrice: '990.75',
        lowPrice: '974.10',
        previousClose: '980.40',
        bidPrice: '985.15',
        askPrice: '985.25',
        volume: BigInt(18200000),
      },
      {
        symbol: 'ICICIBANK',
        exchange: Exchange.NSE,
        name: 'ICICI Bank Limited',
        isin: 'INE090A01021',
        type: InstrumentType.EQUITY,
        lastPrice: '1041.60',
        openPrice: '1029.50',
        highPrice: '1048.20',
        lowPrice: '1026.10',
        previousClose: '1029.45',
        bidPrice: '1041.55',
        askPrice: '1041.65',
        volume: BigInt(11000000),
      },
      {
        symbol: 'INFY',
        exchange: Exchange.NSE,
        name: 'Infosys Limited',
        isin: 'INE009A01021',
        type: InstrumentType.EQUITY,
        lastPrice: '1485.30',
        openPrice: '1465.20',
        highPrice: '1492.75',
        lowPrice: '1460.40',
        previousClose: '1467.25',
        bidPrice: '1485.25',
        askPrice: '1485.35',
        volume: BigInt(10800000),
      },
      {
        symbol: 'ITC',
        exchange: Exchange.NSE,
        name: 'ITC Limited',
        isin: 'INE154A01025',
        type: InstrumentType.EQUITY,
        lastPrice: '445.35',
        openPrice: '451.10',
        highPrice: '452.25',
        lowPrice: '443.80',
        previousClose: '451.30',
        bidPrice: '445.30',
        askPrice: '445.40',
        volume: BigInt(24500000),
      },
      {
        symbol: 'HINDUNILVR',
        exchange: Exchange.NSE,
        name: 'Hindustan Unilever Limited',
        isin: 'INE030A01027',
        type: InstrumentType.EQUITY,
        lastPrice: '2465.10',
        openPrice: '2489.00',
        highPrice: '2492.40',
        lowPrice: '2458.20',
        previousClose: '2486.25',
        bidPrice: '2465.00',
        askPrice: '2465.20',
        volume: BigInt(1780000),
      },
      {
        symbol: 'NESTLEIND',
        exchange: Exchange.NSE,
        name: 'Nestle India Limited',
        isin: 'INE239A01024',
        type: InstrumentType.EQUITY,
        lastPrice: '2235.60',
        openPrice: '2256.40',
        highPrice: '2262.00',
        lowPrice: '2228.70',
        previousClose: '2251.82',
        bidPrice: '2235.50',
        askPrice: '2235.70',
        volume: BigInt(620000),
      },
      {
        symbol: 'LT',
        exchange: Exchange.NSE,
        name: 'Larsen & Toubro Limited',
        isin: 'INE018A01030',
        type: InstrumentType.EQUITY,
        lastPrice: '3120.45',
        openPrice: '3142.00',
        highPrice: '3151.60',
        lowPrice: '3106.20',
        previousClose: '3140.86',
        bidPrice: '3120.35',
        askPrice: '3120.55',
        volume: BigInt(1650000),
      },
      {
        symbol: 'TITAN',
        exchange: Exchange.NSE,
        name: 'Titan Company Limited',
        isin: 'INE280A01028',
        type: InstrumentType.EQUITY,
        lastPrice: '3567.80',
        openPrice: '3588.20',
        highPrice: '3602.40',
        lowPrice: '3554.10',
        previousClose: '3583.93',
        bidPrice: '3567.70',
        askPrice: '3567.90',
        volume: BigInt(980000),
      },
    ];

    await this.prisma.$transaction(async (transaction) => {
      for (const item of instruments) {
        const instrument = await transaction.instrument.upsert({
          where: {
            exchange_symbol: {
              exchange: item.exchange,
              symbol: item.symbol,
            },
          },
          update: {
            name: item.name,
            logoUrl: null,
            isin: item.isin,
            type: item.type,
            currency: 'INR',
            lotSize: 1,
            tickSize: '0.05',
            isActive: true,
          },
          create: {
            symbol: item.symbol,
            exchange: item.exchange,
            name: item.name,
            logoUrl: null,
            isin: item.isin,
            type: item.type,
            currency: 'INR',
            lotSize: 1,
            tickSize: '0.05',
            isActive: true,
          },
        });

        await transaction.marketQuote.upsert({
          where: {
            instrumentId: instrument.id,
          },
          update: {
            lastPrice: item.lastPrice,
            openPrice: item.openPrice,
            highPrice: item.highPrice,
            lowPrice: item.lowPrice,
            previousClose: item.previousClose,
            bidPrice: item.bidPrice,
            askPrice: item.askPrice,
            volume: item.volume,
            source: 'LIVE_FEED',
            asOf,
          },
          create: {
            instrumentId: instrument.id,
            lastPrice: item.lastPrice,
            openPrice: item.openPrice,
            highPrice: item.highPrice,
            lowPrice: item.lowPrice,
            previousClose: item.previousClose,
            bidPrice: item.bidPrice,
            askPrice: item.askPrice,
            volume: item.volume,
            source: 'LIVE_FEED',
            asOf,
          },
        });
      }
    });

    return {
      message: 'Market data initialized',
      initialized: instruments.length,
      source: 'LIVE_FEED',
      asOf,
    };
  }
}
