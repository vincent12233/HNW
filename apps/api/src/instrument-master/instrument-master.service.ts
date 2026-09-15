import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import axios from 'axios';
import { Exchange, InstrumentType } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

type NseEquityRow = {
  symbol: string;
  name: string;
  series: string;
  isin: string | null;
  lotSize: number;
};

/** Product categories that must survive equity-master metadata sync. */
const PROTECTED_INSTRUMENT_CATEGORIES = new Set([
  'INST',
  'INSTITUTIONAL',
  'LIMIT_UP',
  'OTC',
  'BLOCK',
  'BLOCK_TRADE',
  'IPO',
]);

/** Keep Inst/OTC/IPO (and aliases) on update; default new/ordinary rows to EQUITY. */
export function categoryForEquityMasterUpdate(
  existingCategory: string | null | undefined,
): string {
  const raw = (existingCategory ?? '').trim();
  if (PROTECTED_INSTRUMENT_CATEGORIES.has(raw.toUpperCase())) {
    return raw;
  }
  return 'EQUITY';
}

@Injectable()
export class InstrumentMasterService {
  private readonly logger = new Logger(InstrumentMasterService.name);
  private readonly nseEquityUrl: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    this.nseEquityUrl =
      this.config.get<string>('NSE_EQUITY_MASTER_URL')?.trim() ||
      'https://nsearchives.nseindia.com/content/equities/EQUITY_L.csv';
  }

  @Cron('0 0 6 * * *', { timeZone: 'Asia/Kolkata' })
  async scheduledNseSync() {
    try {
      const result = await this.syncNseEquities();
      this.logger.log(
        `NSE instrument master sync completed: ${result.created} created, ${result.updated} updated`,
      );
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`NSE instrument master sync failed: ${message}`);
    }
  }

  @Cron('0 15 6 * * *', { timeZone: 'Asia/Kolkata' })
  async scheduledBseSync() {
    if (!this.config.get<string>('BSE_EQUITY_MASTER_URL')?.trim()) return;
    try {
      await this.syncBseEquities();
    } catch (error: unknown) {
      this.logger.error(
        `BSE instrument master sync failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  async syncNseEquities() {
    const response = await axios.get<string>(this.nseEquityUrl, {
      responseType: 'text',
      timeout: 20000,
      headers: {
        Accept: 'text/csv,*/*',
        'User-Agent': 'india-trading-platform/1.0',
      },
      transformResponse: [(value) => value],
    });

    const rows = this.parseNseEquityCsv(response.data).filter(
      (row) => row.series === 'EQ',
    );

    if (rows.length === 0) {
      throw new Error('NSE equity master returned no EQ securities');
    }

    let created = 0;
    let updated = 0;

    for (const row of rows) {
      const existing = await this.prisma.instrument.findUnique({
        where: {
          exchange_symbol: {
            exchange: Exchange.NSE,
            symbol: row.symbol,
          },
        },
        select: { id: true, category: true },
      });

      if (existing) {
        await this.prisma.instrument.update({
          where: { id: existing.id },
          data: {
            name: row.name,
            isin: row.isin,
            type: InstrumentType.EQUITY,
            currency: 'INR',
            lotSize: row.lotSize,
            category: categoryForEquityMasterUpdate(existing.category),
          },
        });
        updated += 1;
        continue;
      }

      await this.prisma.instrument.create({
        data: {
          exchange: Exchange.NSE,
          symbol: row.symbol,
          name: row.name,
          isin: row.isin,
          type: InstrumentType.EQUITY,
          currency: 'INR',
          lotSize: row.lotSize,
          category: 'EQUITY',
          isActive: false,
        },
      });
      created += 1;
    }

    return {
      source: 'NSE_EQUITY_MASTER',
      totalRows: rows.length,
      created,
      updated,
      newInstrumentsDefaultActive: false,
    };
  }

  async list(params: {
    exchange?: string;
    search?: string;
    active?: boolean;
    page?: number;
    pageSize?: number;
  }) {
    const page = Math.max(1, params.page ?? 1);
    const pageSize = Math.min(200, Math.max(1, params.pageSize ?? 50));
    const search = params.search?.trim();

    if (params.exchange && !['NSE', 'BSE'].includes(params.exchange)) {
      throw new BadRequestException('Unsupported equity exchange');
    }
    const where = {
      exchange: {
        in: params.exchange
          ? [params.exchange as Exchange]
          : [Exchange.NSE, Exchange.BSE],
      },
      type: InstrumentType.EQUITY,
      ...(params.active === undefined ? {} : { isActive: params.active }),
      ...(search
        ? {
            OR: [
              { symbol: { contains: search, mode: 'insensitive' as const } },
              { name: { contains: search, mode: 'insensitive' as const } },
              { isin: { contains: search, mode: 'insensitive' as const } },
            ],
          }
        : {}),
    };

    const libraryWhere = {
      exchange: where.exchange,
      type: InstrumentType.EQUITY,
    };
    const [total, data, libraryTotal, enabledTotal, quotedTotal] =
      await this.prisma.$transaction([
        this.prisma.instrument.count({ where }),
        this.prisma.instrument.findMany({
          where,
          orderBy: [
            { isActive: 'desc' },
            { displayOrder: 'asc' },
            { symbol: 'asc' },
          ],
          skip: (page - 1) * pageSize,
          take: pageSize,
          select: {
            id: true,
            symbol: true,
            exchange: true,
            name: true,
            isin: true,
            category: true,
            lotSize: true,
            tickSize: true,
            displayOrder: true,
            isActive: true,
            updatedAt: true,
            quote: {
              select: {
                lastPrice: true,
                asOf: true,
              },
            },
          },
        }),
        this.prisma.instrument.count({ where: libraryWhere }),
        this.prisma.instrument.count({
          where: { ...libraryWhere, isActive: true },
        }),
        this.prisma.instrument.count({
          where: { ...libraryWhere, quote: { is: { lastPrice: { gt: 0 } } } },
        }),
      ]);

    return {
      data,
      total,
      page,
      pageSize,
      statistics: {
        total: libraryTotal,
        enabled: enabledTotal,
        quoted: quotedTotal,
      },
      autoSync: {
        nse: true,
        bse: !!this.config.get<string>('BSE_EQUITY_MASTER_URL')?.trim(),
      },
    };
  }

  async enableAll(actorId: string, exchange?: string) {
    if (exchange && !['NSE', 'BSE'].includes(exchange))
      throw new BadRequestException('Unsupported equity exchange');
    const exchanges = exchange
      ? [exchange as Exchange]
      : [Exchange.NSE, Exchange.BSE];
    return this.prisma.$transaction(async (tx) => {
      const result = await tx.instrument.updateMany({
        where: {
          exchange: { in: exchanges },
          type: InstrumentType.EQUITY,
          isActive: false,
        },
        data: { isActive: true },
      });
      await tx.auditLog.create({
        data: {
          actorId,
          action: 'INSTRUMENTS_ENABLE_ALL',
          resource: 'INSTRUMENT',
          metadata: { exchanges, type: 'EQUITY', updated: result.count },
        },
      });
      return { updated: result.count };
    });
  }

  async setActive(instrumentId: string, isActive: boolean) {
    return this.prisma.instrument.update({
      where: { id: instrumentId },
      data: { isActive },
      select: {
        id: true,
        symbol: true,
        exchange: true,
        name: true,
        isActive: true,
      },
    });
  }

  async setBulkActive(symbols: string[], isActive: boolean) {
    const normalized = Array.from(
      new Set(
        symbols
          .map((symbol) => symbol.trim().toUpperCase())
          .filter((symbol) => symbol.length > 0),
      ),
    );

    if (normalized.length === 0) {
      return { updated: 0, symbols: [] as string[] };
    }

    const result = await this.prisma.instrument.updateMany({
      where: {
        exchange: Exchange.NSE,
        type: InstrumentType.EQUITY,
        symbol: { in: normalized },
      },
      data: { isActive },
    });

    return { updated: result.count, symbols: normalized, isActive };
  }

  async setBulkActiveByIds(instrumentIds: string[], isActive: boolean) {
    if (instrumentIds.some((id) => typeof id !== 'string')) {
      throw new BadRequestException('Invalid instrument IDs');
    }
    const result = await this.prisma.instrument.updateMany({
      where: {
        id: { in: [...new Set(instrumentIds)] },
        exchange: { in: [Exchange.NSE, Exchange.BSE] },
        type: InstrumentType.EQUITY,
      },
      data: { isActive },
    });
    return { updated: result.count, isActive };
  }

  async syncBseEquities() {
    const url = this.config.get<string>('BSE_EQUITY_MASTER_URL')?.trim();
    if (!url) {
      throw new BadRequestException(
        'BSE equity master source is not configured (BSE_EQUITY_MASTER_URL)',
      );
    }
    const response = await axios.get<string>(url, {
      responseType: 'text',
      timeout: 20000,
      maxContentLength: 10 * 1024 * 1024,
      transformResponse: [(value) => value],
    });
    const rows = this.parseBseEquityCsv(response.data);
    if (!rows.length)
      throw new BadRequestException('BSE equity master returned no securities');
    let created = 0;
    let updated = 0;
    for (const row of rows) {
      const existing = await this.prisma.instrument.findUnique({
        where: {
          exchange_symbol: { exchange: Exchange.BSE, symbol: row.symbol },
        },
        select: { id: true, category: true },
      });
      const data = {
        name: row.name,
        isin: row.isin,
        type: InstrumentType.EQUITY,
        currency: 'INR',
        lotSize: row.lotSize,
        category: existing
          ? categoryForEquityMasterUpdate(existing.category)
          : 'EQUITY',
      };
      if (existing) {
        await this.prisma.instrument.update({
          where: { id: existing.id },
          data,
        });
        updated++;
      } else {
        await this.prisma.instrument.create({
          data: {
            ...data,
            exchange: Exchange.BSE,
            symbol: row.symbol,
            isActive: false,
          },
        });
        created++;
      }
    }
    return {
      source: 'BSE_EQUITY_MASTER',
      totalRows: rows.length,
      created,
      updated,
      newInstrumentsDefaultActive: false,
    };
  }

  parseBseEquityCsv(csv: string): Omit<NseEquityRow, 'series'>[] {
    const table = this.parseCsv(csv.replace(/^\uFEFF/, ''));
    if (table.length < 2) return [];
    const headers = table[0].map((value) => value.trim().toUpperCase());
    const indexOf = (...names: string[]) =>
      names.map((name) => headers.indexOf(name)).find((index) => index >= 0) ??
      -1;
    const symbolIndex = indexOf(
      'SECURITY CODE',
      'SCRIP CODE',
      'SC_CODE',
      'SYMBOL',
    );
    const nameIndex = indexOf('SECURITY NAME', 'SC_NAME', 'NAME');
    const isinIndex = indexOf('ISIN NO', 'ISIN NUMBER', 'ISIN_CODE', 'ISIN');
    const lotIndex = indexOf('MARKET LOT', 'LOT SIZE');
    if (symbolIndex < 0 || nameIndex < 0)
      throw new BadRequestException('Unexpected BSE equity CSV headers');
    const rows = new Map<string, Omit<NseEquityRow, 'series'>>();
    for (const columns of table.slice(1)) {
      const symbol = columns[symbolIndex]?.trim().toUpperCase() ?? '';
      const name = columns[nameIndex]?.trim() ?? '';
      if (!symbol || !name) continue;
      if (!/^[A-Z0-9&._-]+$/.test(symbol))
        throw new BadRequestException('Invalid BSE security code');
      const lotSize = Number(columns[lotIndex]?.trim() || '1');
      rows.set(symbol, {
        symbol,
        name,
        isin: columns[isinIndex]?.trim() || null,
        lotSize: Number.isInteger(lotSize) && lotSize > 0 ? lotSize : 1,
      });
    }
    return [...rows.values()];
  }

  parseNseEquityCsv(csv: string): NseEquityRow[] {
    const table = this.parseCsv(csv.replace(/^\uFEFF/, ''));
    if (table.length < 2) return [];

    const headers = table[0].map((value) => value.trim().toUpperCase());
    const indexOf = (...names: string[]) =>
      names.map((name) => headers.indexOf(name)).find((index) => index >= 0) ??
      -1;

    const symbolIndex = indexOf('SYMBOL');
    const nameIndex = indexOf('NAME OF COMPANY', 'COMPANY NAME');
    const seriesIndex = indexOf('SERIES');
    const isinIndex = indexOf('ISIN NUMBER', 'ISIN');
    const lotIndex = indexOf('MARKET LOT', 'LOT SIZE');

    if (symbolIndex < 0 || nameIndex < 0 || seriesIndex < 0) {
      throw new Error('Unexpected NSE equity master CSV headers');
    }

    return table.slice(1).flatMap((columns) => {
      const symbol = columns[symbolIndex]?.trim().toUpperCase() ?? '';
      const name = columns[nameIndex]?.trim() ?? '';
      const series = columns[seriesIndex]?.trim().toUpperCase() ?? '';
      if (!symbol || !name || !series) return [];

      const lotSize = Number.parseInt(columns[lotIndex]?.trim() ?? '1', 10);
      const isin = isinIndex >= 0 ? columns[isinIndex]?.trim() || null : null;

      return [
        {
          symbol,
          name,
          series,
          isin,
          lotSize: Number.isFinite(lotSize) && lotSize > 0 ? lotSize : 1,
        },
      ];
    });
  }

  private parseCsv(input: string): string[][] {
    const rows: string[][] = [];
    let row: string[] = [];
    let field = '';
    let quoted = false;

    for (let index = 0; index < input.length; index += 1) {
      const char = input[index];

      if (quoted) {
        if (char === '"' && input[index + 1] === '"') {
          field += '"';
          index += 1;
        } else if (char === '"') {
          quoted = false;
        } else {
          field += char;
        }
        continue;
      }

      if (char === '"') {
        quoted = true;
      } else if (char === ',') {
        row.push(field);
        field = '';
      } else if (char === '\n') {
        row.push(field.replace(/\r$/, ''));
        if (row.some((value) => value.length > 0)) rows.push(row);
        row = [];
        field = '';
      } else {
        field += char;
      }
    }

    if (field.length > 0 || row.length > 0) {
      row.push(field.replace(/\r$/, ''));
      if (row.some((value) => value.length > 0)) rows.push(row);
    }

    return rows;
  }
}
