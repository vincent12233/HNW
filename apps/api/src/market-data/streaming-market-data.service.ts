import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { MarketDataHealthService } from './market-data-health.service';
import { QuoteIngestionService } from './quote-ingestion.service';
import { StreamingProviderRegistryService } from './providers/streaming-provider-registry.service';
import {
  MarketSubscription,
  StreamingMarketDataProvider,
} from './providers/streaming-market-data-provider.interface';

@Injectable()
export class StreamingMarketDataService
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(StreamingMarketDataService.name);
  private reconnectTimer?: NodeJS.Timeout;
  private stopped = false;
  private connecting = false;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly ingestion: QuoteIngestionService,
    private readonly registry: StreamingProviderRegistryService,
    private readonly health: MarketDataHealthService,
  ) {}

  async onModuleInit() {
    if (!this.isEnabled()) {
      this.health.setStreamingStatus('NONE', false, {
        subscriptionCount: 0,
        providerSymbolCount: 0,
        lastConnectionError: null,
      });
      this.logger.log(
        'Streaming market data is disabled; polling fallback remains active',
      );
      return;
    }

    await this.start(true);
  }

  async onModuleDestroy() {
    this.stopped = true;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);

    const provider = this.registry.provider;
    if (provider) {
      try {
        await provider.disconnect();
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        this.logger.warn(`Streaming provider disconnect failed: ${message}`);
      }
    }
    this.health.setStreamingStatus(provider?.name ?? 'NONE', false);
  }

  async start(failFast = false) {
    if (this.connecting || this.stopped) return;

    const provider = this.registry.provider;
    if (!provider) {
      this.health.setStreamingStatus('NONE', false, {
        subscriptionCount: 0,
        providerSymbolCount: 0,
        lastConnectionError:
          'Streaming market data is enabled but no streaming provider is configured',
      });
      const message =
        'Streaming market data is enabled but no streaming provider is configured';
      if (failFast) throw new Error(message);
      this.logger.warn(`${message}; polling fallback remains active`);
      return;
    }

    this.health.setStreamingStatus(provider.name, false, {
      lastConnectionError: null,
    });
    this.connecting = true;
    try {
      this.bindQuotes(provider);
      const subscriptions = await this.loadSubscriptions();
      await provider.subscribe(subscriptions);
      this.health.setStreamingStatus(provider.name, false, {
        subscriptionCount: subscriptions.length,
        providerSymbolCount:
          provider.providerSymbolCount ?? subscriptions.length,
        lastConnectionError: null,
      });
      await provider.connect();
      this.health.setStreamingStatus(provider.name, true, {
        subscriptionCount: subscriptions.length,
        providerSymbolCount:
          provider.providerSymbolCount ?? subscriptions.length,
        lastConnectionError: null,
      });
      this.logger.log(`Streaming market data connected via ${provider.name}`);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.health.setStreamingStatus(provider.name, false, {
        providerSymbolCount: provider.providerSymbolCount ?? 0,
        lastConnectionError: message,
      });
      this.logger.error(`Streaming market data connection failed: ${message}`);
      if (failFast) throw error;
      this.scheduleReconnect();
    } finally {
      this.connecting = false;
    }
  }

  async restoreSubscriptions() {
    const provider = this.registry.provider;
    if (!provider) return;
    const subscriptions = await this.loadSubscriptions();
    await provider.subscribe(subscriptions);
    this.health.setStreamingStatus(provider.name, undefined, {
      subscriptionCount: subscriptions.length,
      providerSymbolCount: provider.providerSymbolCount ?? subscriptions.length,
    });
  }

  private bindQuotes(provider: StreamingMarketDataProvider) {
    provider.onQuote((quote) => {
      void this.ingestion
        .ingest(quote.exchange, quote, 'STOCK')
        .catch((error: unknown) => {
          const message = error instanceof Error ? error.message : String(error);
          this.logger.error(
            `Streaming quote ingestion failed for ${quote.exchange}:${quote.symbol}: ${message}`,
          );
        });
    });
  }

  private async loadSubscriptions(): Promise<MarketSubscription[]> {
    const instruments = await this.prisma.instrument.findMany({
      where: {
        isActive: true,
        exchange: { in: ['NSE', 'BSE'] },
      },
      select: { symbol: true, exchange: true },
      orderBy: [{ displayOrder: 'asc' }, { symbol: 'asc' }],
    });

    return instruments.map((instrument) => ({
      symbol: instrument.symbol,
      exchange: instrument.exchange,
    }));
  }

  private scheduleReconnect() {
    if (this.stopped || this.reconnectTimer) return;
    const reconnectMs = this.positiveInteger(
      this.config.get<string>('MARKET_DATA_RECONNECT_MS'),
      5000,
    );
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = undefined;
      void this.start();
    }, reconnectMs);
  }

  private isEnabled() {
    return (
      (this.config.get<string>('MARKET_DATA_STREAMING_ENABLED') ?? 'false')
        .trim()
        .toLowerCase() === 'true'
    );
  }

  private positiveInteger(value: string | undefined, fallback: number) {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
