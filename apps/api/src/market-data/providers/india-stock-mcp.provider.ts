import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import {
  MarketDataProvider,
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

  constructor(private readonly config: ConfigService) {}

  async onModuleDestroy() {
    if (this.client) {
      await this.client.close().catch(() => undefined);
      this.client = undefined;
    }
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
      this.logger.log('India Stock MCP provider connected');
      return client;
    } catch (error) {
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

  private toQuote(payload: QuotePayload, requestedSymbol: string): MarketQuoteResult {
    const price = this.number(payload.price ?? payload.last ?? payload.lastPrice);
    if (price === null || price <= 0) {
      throw new Error(`Invalid price returned for ${requestedSymbol}`);
    }

    const absoluteChange = this.number(payload.change ?? payload.variation);
    const explicitChangePct = this.number(
      payload.changePct ?? payload.percentChange ?? payload.pChange,
    );
    const explicitPreviousClose = this.number(
      payload.previousClose ?? payload.prevClose,
    );
    const previousClose =
      explicitPreviousClose ??
      (absoluteChange !== null ? price - absoluteChange : null) ??
      (explicitChangePct !== null && explicitChangePct !== -100
        ? price / (1 + explicitChangePct / 100)
        : price);
    const changePct =
      explicitChangePct ??
      (previousClose > 0 ? ((price - previousClose) / previousClose) * 100 : 0);

    return {
      symbol: this.cleanSymbol(payload.symbol, requestedSymbol),
      price: String(price),
      previousClose: String(previousClose),
      openPrice: this.stringNumber(payload.open ?? payload.openPrice),
      highPrice: this.stringNumber(payload.dayHigh ?? payload.high ?? payload.highPrice),
      lowPrice: this.stringNumber(payload.dayLow ?? payload.low ?? payload.lowPrice),
      bidPrice: this.stringNumber(payload.bid ?? payload.bidPrice),
      askPrice: this.stringNumber(payload.ask ?? payload.askPrice),
      volume: String(this.number(payload.volume) ?? 0),
      change: Number(changePct.toFixed(2)),
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
    const parsed = this.number(value);
    return parsed === null ? null : String(parsed);
  }

  private number(value: unknown): number | null {
    if (typeof value === 'number') return Number.isFinite(value) ? value : null;
    if (typeof value !== 'string') return null;
    const parsed = Number(value.replace(/,/g, '').trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
}
