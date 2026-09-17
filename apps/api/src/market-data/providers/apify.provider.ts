import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError } from 'axios';
import {
  MarketDataProvider,
  MarketQuoteRequest,
  MarketQuoteResult,
} from './market-data-provider.interface';
import {
  isPlaceholderApifyToken,
  normalizeApifyQuote,
  parseApifyActorId,
  selectMatchingItem,
  type ApifyDatasetItem,
} from './apify-quote.normalizer';
import {
  instrumentKey,
  normalizeApifyExchange,
  normalizeApifySymbol,
} from './apify-symbol';

@Injectable()
export class ApifyProvider implements MarketDataProvider {
  readonly name = 'APIFY';
  private readonly logger = new Logger(ApifyProvider.name);

  constructor(private readonly config: ConfigService) {}

  isConfigured(): boolean {
    return !isPlaceholderApifyToken(this.token()) && !!this.actorId();
  }

  async getQuote(symbol: string, exchange = 'NSE'): Promise<MarketQuoteResult> {
    const quotes = await this.getQuotes([{ symbol, exchange }]);
    const expected = instrumentKey(exchange, symbol);
    const match = quotes.find(
      (quote) =>
        instrumentKey(quote.exchange ?? exchange, quote.symbol) === expected,
    );
    if (!match) {
      throw new Error(`Apify quote missing for ${exchange}:${symbol}`);
    }
    return match;
  }

  async getQuotes(
    requests: MarketQuoteRequest[],
  ): Promise<MarketQuoteResult[]> {
    this.assertConfigured();
    if (!requests.length) return [];

    const receivedAt = new Date();
    const groups = this.groupByExchange(requests);
    const quotes: MarketQuoteResult[] = [];

    for (const [exchange, symbols] of groups) {
      const items = await this.runActor(exchange, symbols);
      for (const request of requests.filter(
        (item) => item.exchange === exchange,
      )) {
        const row = selectMatchingItem(items, request);
        if (!row) {
          this.logger.warn(
            `Apify batch missed ${request.exchange}:${request.symbol}`,
          );
          continue;
        }
        try {
          quotes.push(normalizeApifyQuote(row, request, receivedAt));
        } catch (error: unknown) {
          const message =
            error instanceof Error ? error.message : String(error);
          this.logger.error(
            `Apify normalize failed ${request.exchange}:${request.symbol}: ${message}`,
          );
        }
      }
    }

    return quotes;
  }

  private groupByExchange(requests: MarketQuoteRequest[]) {
    const groups = new Map<string, string[]>();
    for (const request of requests) {
      const exchange = normalizeApifyExchange(request.exchange);
      const symbol = normalizeApifySymbol(request.symbol);
      const symbols = groups.get(exchange) ?? [];
      if (!symbols.includes(symbol)) symbols.push(symbol);
      groups.set(exchange, symbols);
    }
    return groups;
  }

  private async runActor(
    exchange: string,
    symbols: string[],
  ): Promise<ApifyDatasetItem[]> {
    const timeoutMs = this.timeoutMs();
    const url = `${this.apiBase()}/v2/acts/${encodeURIComponent(parseApifyActorId(this.actorId()))}/run-sync-get-dataset-items`;
    const started = Date.now();
    try {
      const response = await axios.post<unknown>(
        url,
        {
          symbols,
          exchange,
          dataType: 'quote',
        },
        {
          timeout: timeoutMs,
          headers: {
            Authorization: `Bearer ${this.token()}`,
            'content-type': 'application/json',
          },
          validateStatus: (status) => status >= 200 && status < 300,
        },
      );
      this.logger.log(
        JSON.stringify({
          provider: this.name,
          exchange,
          batchCount: symbols.length,
          durationMs: Date.now() - started,
        }),
      );
      if (!Array.isArray(response.data)) {
        throw new Error('Apify response is not a dataset array');
      }
      return response.data as ApifyDatasetItem[];
    } catch (error: unknown) {
      const message = this.safeErrorMessage(error);
      this.logger.error(
        JSON.stringify({
          provider: this.name,
          exchange,
          batchCount: symbols.length,
          durationMs: Date.now() - started,
          message,
        }),
      );
      throw new Error(`Apify snapshot request failed: ${message}`, {
        cause: error,
      });
    }
  }

  private assertConfigured() {
    if (!this.isConfigured()) {
      throw new Error(
        'MARKET_DATA_PROVIDER=APIFY requires APIFY_TOKEN and APIFY_ACTOR_ID',
      );
    }
  }

  private token() {
    return this.config.get<string>('APIFY_TOKEN')?.trim() ?? '';
  }

  private actorId() {
    return this.config.get<string>('APIFY_ACTOR_ID')?.trim() ?? '';
  }

  private apiBase() {
    return (
      this.config.get<string>('APIFY_API_BASE_URL')?.trim() ||
      'https://api.apify.com'
    );
  }

  private timeoutMs() {
    const parsed = Number(
      this.config.get<string>('APIFY_MARKET_DATA_TIMEOUT_MS'),
    );
    return Number.isInteger(parsed) && parsed > 0 ? parsed : 30000;
  }

  private safeErrorMessage(error: unknown): string {
    if (axios.isAxiosError(error)) {
      const axiosError = error as AxiosError;
      if (axiosError.code === 'ECONNABORTED') return 'timeout';
      const status = axiosError.response?.status;
      return status ? `HTTP ${status}` : axiosError.code || 'request failed';
    }
    if (error instanceof Error) {
      return error.message.replace(/Bearer\s+\S+/gi, 'Bearer [redacted]');
    }
    return 'request failed';
  }
}
