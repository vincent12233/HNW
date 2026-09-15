import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { Prisma } from '../../generated/prisma/client';
import {
  MarketDataProvider,
  MarketHistoryPoint,
  MarketQuoteResult,
} from './market-data-provider.interface';

type QuotePayload = Record<string, unknown>;

@Injectable()
export class IndiaStockMcpProvider
  implements MarketDataProvider, OnModuleDestroy
{
  readonly name = 'INDIA_STOCK_MCP';
  private readonly logger = new Logger(IndiaStockMcpProvider.name);
  private client?: Client;
  private connecting?: Promise<Client>;
  private availableTools = new Set<string>();

  constructor(private readonly config: ConfigService) {}

  async onModuleDestroy() {
    if (this.client) {
      await this.client.close().catch(() => undefined);
      this.client = undefined;
    }
    this.availableTools.clear();
  }

  async getQuote(symbol: string, exchange = 'NSE'): Promise<MarketQuoteResult> {
    const client = await this.getClient();
    const normalizedSymbol = this.normalizeSymbol(symbol, exchange);
    const index = this.isIndexSymbol(symbol);
    const result = await client.callTool({
      name: index ? 'get_index' : 'get_quote',
      arguments: index ? { index: normalizedSymbol } : { symbol: normalizedSymbol },
    });

    return this.toQuote(this.parsePayload(result.content), symbol);
  }

  async supportsHistorical() {
    await this.getClient();
    return this.availableTools.has('get_historical');
  }

  async getHistorical(
    symbol: string,
    from: string,
    to: string,
    interval: '1d' | '1wk' | '1mo' = '1d',
  ): Promise<MarketHistoryPoint[]> {
    const client = await this.getClient();
    if (!this.availableTools.has('get_historical')) {
      throw new Error('india-stock-mcp does not expose get_historical');
    }

    const result = await client.callTool({
      name: 'get_historical',
      arguments: {
        symbol: this.normalizeSymbol(symbol, 'NSE'),
        from,
        to,
        interval,
      },
    });
    const text = this.toolText(result.content);
    if (!text) return [];
    if (text.startsWith('Error:')) throw new Error(text.slice(6).trim());

    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`Unable to parse India Stock MCP history: ${message}`);
    }

    const rows = this.historyRows(parsed);
    return rows
      .map((row) => this.historyPoint(row))
      .filter((point): point is MarketHistoryPoint => point !== null)
      .sort((left, right) => left.date.localeCompare(right.date));
  }

  private async getClient(): Promise<Client> {
    if (this.client) return this.client;
    if (this.connecting) return this.connecting;
    this.connecting = this.connect();
    try {
      this.client = await this.connecting;
      return this.client;
    } finally {
      this.connecting = undefined;
    }
  }

  private async connect(): Promise<Client> {
    const command =
      this.config.get<string>('INDIA_STOCK_MCP_COMMAND')?.trim() ||
      (process.platform === 'win32' ? 'npx.cmd' : 'npx');
    const packageName =
      this.config.get<string>('INDIA_STOCK_MCP_PACKAGE')?.trim() ||
      'india-stock-mcp';
    const client = new Client({
      name: 'india-trading-platform-api',
      version: '1.0.0',
    });
    const transport = new StdioClientTransport({
      command,
      args: ['--no-install', packageName],
      stderr: 'pipe',
    });

    transport.stderr?.on('data', (chunk: Buffer) => {
      const message = chunk.toString().trim();
      if (message) this.logger.debug(message);
    });

    try {
      await client.connect(transport);
      const names = new Set((await client.listTools()).tools.map((tool) => tool.name));
      if (!names.has('get_quote') || !names.has('get_index')) {
        await client.close().catch(() => undefined);
        throw new Error('india-stock-mcp does not expose required quote/index tools');
      }
      this.availableTools = names;
      this.logger.log('India Stock MCP provider connected');
      return client;
    } catch (error) {
      this.availableTools.clear();
      await client.close().catch(() => undefined);
      throw error;
    }
  }

  private parsePayload(content: unknown): QuotePayload {
    const text = this.toolText(content);
    if (!text) throw new Error('India Stock MCP returned an empty quote');
    if (text.startsWith('Error:')) throw new Error(text.slice(6).trim());

    try {
      const parsed = JSON.parse(text);
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        throw new Error('Unexpected quote payload');
      }
      return parsed as QuotePayload;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`Unable to parse India Stock MCP quote: ${message}`);
    }
  }

  private toolText(content: unknown): string {
    if (!Array.isArray(content)) return '';
    return content
      .filter(
        (item): item is { type: 'text'; text: string } =>
          !!item &&
          typeof item === 'object' &&
          (item as { type?: unknown }).type === 'text' &&
          typeof (item as { text?: unknown }).text === 'string',
      )
      .map((item) => item.text)
      .join('\n')
      .trim();
  }

  private historyRows(payload: unknown): Record<string, unknown>[] {
    if (Array.isArray(payload)) {
      return payload.filter(
        (row): row is Record<string, unknown> =>
          !!row && typeof row === 'object' && !Array.isArray(row),
      );
    }
    if (!payload || typeof payload !== 'object') return [];
    const object = payload as Record<string, unknown>;
    for (const key of ['data', 'history', 'historical', 'prices']) {
      const value = object[key];
      if (Array.isArray(value)) return this.historyRows(value);
    }
    return [];
  }

  private historyPoint(row: Record<string, unknown>): MarketHistoryPoint | null {
    const open = this.number(row.open ?? row.openPrice);
    const high = this.number(row.high ?? row.highPrice);
    const low = this.number(row.low ?? row.lowPrice);
    const close = this.number(row.close ?? row.price ?? row.lastPrice);
    if (
      open === null ||
      high === null ||
      low === null ||
      close === null ||
      close <= 0
    ) {
      return null;
    }

    const rawDate = row.date ?? row.datetime ?? row.timestamp ?? row.time;
    const date = this.historyDate(rawDate);
    if (!date) return null;

    return {
      date,
      open,
      high,
      low,
      close,
      volume: this.number(row.volume) ?? 0,
    };
  }

  private historyDate(value: unknown): string | null {
    if (typeof value === 'number' && Number.isFinite(value)) {
      const milliseconds = value > 100000000000 ? value : value * 1000;
      return new Date(milliseconds).toISOString();
    }
    if (typeof value !== 'string' || !value.trim()) return null;
    const text = value.trim();
    const parsed = /^\d{4}-\d{2}-\d{2}$/.test(text)
      ? new Date(`${text}T00:00:00+05:30`)
      : new Date(text);
    return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
  }

  private toQuote(payload: QuotePayload, requestedSymbol: string): MarketQuoteResult {
    const priceText = this.stringNumber(
      payload.price ?? payload.last ?? payload.lastPrice,
    );
    if (priceText == null) {
      throw new Error(`Invalid price returned for ${requestedSymbol}`);
    }
    const price = new Prisma.Decimal(priceText);
    if (price.lte(0)) {
      throw new Error(`Invalid price returned for ${requestedSymbol}`);
    }

    const absoluteChangeText = this.stringNumber(
      payload.change ?? payload.variation,
    );
    const explicitChangePct = this.number(
      payload.changePct ?? payload.percentChange ?? payload.pChange,
    );
    const explicitPreviousCloseText = this.stringNumber(
      payload.previousClose ?? payload.prevClose,
    );
    const previousClose = explicitPreviousCloseText
      ? new Prisma.Decimal(explicitPreviousCloseText)
      : absoluteChangeText != null
        ? price.sub(absoluteChangeText)
        : explicitChangePct !== null && explicitChangePct !== -100
          ? price.div(
              new Prisma.Decimal(1).add(
                new Prisma.Decimal(explicitChangePct).div(100),
              ),
            )
          : price;
    const changePct =
      explicitChangePct ??
      (previousClose.gt(0)
        ? Number(
            price
              .sub(previousClose)
              .div(previousClose)
              .mul(100)
              .toDecimalPlaces(2)
              .toFixed(),
          )
        : 0);

    return {
      symbol: this.cleanSymbol(payload.symbol, requestedSymbol),
      price: priceText,
      previousClose: previousClose
        .toDecimalPlaces(4, Prisma.Decimal.ROUND_HALF_UP)
        .toFixed(),
      openPrice: this.stringNumber(payload.open ?? payload.openPrice),
      highPrice: this.stringNumber(
        payload.dayHigh ?? payload.high ?? payload.highPrice,
      ),
      lowPrice: this.stringNumber(
        payload.dayLow ?? payload.low ?? payload.lowPrice,
      ),
      bidPrice: this.stringNumber(payload.bid ?? payload.bidPrice),
      askPrice: this.stringNumber(payload.ask ?? payload.askPrice),
      volume: this.stringNumber(payload.volume) ?? '0',
      change: Number(new Prisma.Decimal(changePct).toDecimalPlaces(2).toFixed()),
      source: this.name,
      updatedAt: new Date(),
    };
  }

  private isIndexSymbol(symbol: string) {
    const value = symbol.trim().toUpperCase();
    return new Set([
      'NIFTY50',
      'NIFTY 50',
      'BANKNIFTY',
      'NIFTY BANK',
      'SENSEX',
      'BSE SENSEX',
    ]).has(value);
  }

  private normalizeSymbol(symbol: string, exchange: string) {
    const value = symbol.trim().toUpperCase().replace(/\.(NS|BO)$/i, '');
    const indexAliases: Record<string, string> = {
      NIFTY50: 'NIFTY 50',
      BANKNIFTY: 'NIFTY BANK',
    };
    if (indexAliases[value]) return indexAliases[value];
    if (exchange.trim().toUpperCase() === 'BSE' && /^\d{6}$/.test(value)) return value;
    return value;
  }

  private cleanSymbol(value: unknown, fallback: string) {
    const symbol = typeof value === 'string' ? value : fallback;
    return symbol.trim().toUpperCase().replace(/\.(NS|BO)$/i, '');
  }

  private stringNumber(value: unknown): string | null {
    try {
      const decimal = new Prisma.Decimal(
        typeof value === 'string' ? value.replace(/,/g, '').trim() : (value as any),
      );
      if (!decimal.isFinite()) return null;
      return decimal.toDecimalPlaces(4, Prisma.Decimal.ROUND_HALF_UP).toFixed();
    } catch {
      return null;
    }
  }

  private number(value: unknown): number | null {
    const text = this.stringNumber(value);
    if (text == null) return null;
    const parsed = Number(text);
    return Number.isFinite(parsed) ? parsed : null;
  }
}
