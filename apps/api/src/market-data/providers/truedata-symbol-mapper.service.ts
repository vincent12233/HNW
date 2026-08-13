import { Injectable } from '@nestjs/common';

@Injectable()
export class TrueDataSymbolMapperService {
  toProviderSymbol(symbol: string, exchange: string) {
    const normalizedSymbol = symbol.trim().toUpperCase();
    const normalizedExchange = exchange.trim().toUpperCase();

    if (normalizedExchange === 'NSE') {
      if (normalizedSymbol === 'NIFTY50') return 'NIFTY 50';
      if (normalizedSymbol === 'BANKNIFTY') return 'NIFTY BANK';
      return normalizedSymbol;
    }

    if (normalizedExchange === 'BSE') {
      if (normalizedSymbol === 'SENSEX') return 'SENSEX';
      return normalizedSymbol;
    }

    return normalizedSymbol;
  }

  fromProviderSymbol(symbol: string) {
    const normalized = symbol.trim().toUpperCase();

    if (normalized === 'NIFTY 50') {
      return { symbol: 'NIFTY50', exchange: 'NSE' };
    }

    if (normalized === 'NIFTY BANK') {
      return { symbol: 'BANKNIFTY', exchange: 'NSE' };
    }

    if (normalized === 'SENSEX') {
      return { symbol: 'SENSEX', exchange: 'BSE' };
    }

    return { symbol: normalized, exchange: 'NSE' };
  }
}
