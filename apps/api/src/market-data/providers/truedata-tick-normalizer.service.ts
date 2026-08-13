import { BadRequestException, Injectable } from '@nestjs/common';
import { MarketQuoteResult } from './market-data-provider.interface';
import { TrueDataSymbolMapperService } from './truedata-symbol-mapper.service';

@Injectable()
export class TrueDataTickNormalizerService {
  constructor(private readonly symbols: TrueDataSymbolMapperService) {}

  fromArray(
    values: unknown[],
    exchangeOverride?: string,
  ): MarketQuoteResult & { exchange: string } {
    if (!Array.isArray(values) || values.length < 19) {
      throw new BadRequestException('Invalid TrueData tick payload');
    }

    const providerSymbol = String(values[0] ?? '').trim();
    const mapped = this.symbols.fromProviderSymbol(providerSymbol);
    const exchange = (exchangeOverride ?? mapped.exchange).trim().toUpperCase();
    const updatedAt = this.toDate(values[1]);
    const ltp = this.toRequiredNumber(values[2], 'LTP');
    const volume = this.toOptionalNumber(values[5]) ?? 0;
    const open = this.toOptionalNumber(values[6]);
    const high = this.toOptionalNumber(values[7]);
    const low = this.toOptionalNumber(values[8]);
    const previousClose = this.toOptionalNumber(values[9]) ?? ltp;
    const bid = this.toOptionalNumber(values[15]);
    const ask = this.toOptionalNumber(values[17]);
    const change =
      previousClose > 0 ? ((ltp - previousClose) / previousClose) * 100 : 0;

    return {
      symbol: mapped.symbol,
      exchange,
      price: String(ltp),
      previousClose: String(previousClose),
      openPrice: open === null ? null : String(open),
      highPrice: high === null ? null : String(high),
      lowPrice: low === null ? null : String(low),
      bidPrice: bid === null ? null : String(bid),
      askPrice: ask === null ? null : String(ask),
      volume: String(volume),
      change: Number(change.toFixed(2)),
      source: 'TRUEDATA',
      updatedAt,
    };
  }

  private toRequiredNumber(value: unknown, field: string) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
      throw new BadRequestException(`Invalid TrueData ${field}`);
    }
    return parsed;
  }

  private toOptionalNumber(value: unknown): number | null {
    if (value === null || value === undefined || value === '') return null;
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  private toDate(value: unknown) {
    if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
    const date = new Date(String(value));
    if (!Number.isNaN(date.getTime())) return date;
    return new Date();
  }
}
