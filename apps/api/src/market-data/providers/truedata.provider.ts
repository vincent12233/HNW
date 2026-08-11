import { Injectable } from '@nestjs/common';
import { MarketQuoteResult } from './market-data-provider.interface';
import {
  MarketSubscription,
  StreamingMarketDataProvider,
} from './streaming-market-data-provider.interface';
import { TrueDataNodeTransportService } from './truedata-node-transport.service';
import { TrueDataSubscriptionPolicyService } from './truedata-subscription-policy.service';
import { TrueDataSymbolMapperService } from './truedata-symbol-mapper.service';
import { TrueDataTickNormalizerService } from './truedata-tick-normalizer.service';

@Injectable()
export class TrueDataProvider implements StreamingMarketDataProvider {
  readonly name = 'TRUEDATA';
  private handler?: (quote: MarketQuoteResult & { exchange: string }) => void;
  private subscriptions: string[] = [];
  private subscriptionBatches: string[][] = [];
  private connected = false;
  private readonly exchangeByProviderSymbol = new Map<string, string>();

  constructor(
    private readonly symbols: TrueDataSymbolMapperService,
    private readonly normalizer: TrueDataTickNormalizerService,
    private readonly subscriptionPolicy: TrueDataSubscriptionPolicyService,
    private readonly transport: TrueDataNodeTransportService,
  ) {}

  async connect(): Promise<void> {
    if (this.subscriptions.length === 0) {
      throw new Error('TrueData requires at least one staged subscription');
    }

    this.transport.connect(this.subscriptions, (values) =>
      this.ingestRawTick(values),
    );
    this.connected = true;
  }

  async disconnect(): Promise<void> {
    this.transport.disconnect();
    this.connected = false;
    this.subscriptions = [];
    this.subscriptionBatches = [];
    this.exchangeByProviderSymbol.clear();
  }

  async subscribe(subscriptions: MarketSubscription[]): Promise<void> {
    const providerSymbols = subscriptions.map((item) => {
      const providerSymbol = this.symbols.toProviderSymbol(
        item.symbol,
        item.exchange,
      );
      this.exchangeByProviderSymbol.set(
        providerSymbol.trim().toUpperCase(),
        item.exchange.trim().toUpperCase(),
      );
      return providerSymbol;
    });

    const policy = this.subscriptionPolicy.validateAndBatch(providerSymbols);
    const previous = new Set(this.subscriptions);
    this.subscriptions = policy.symbols;
    this.subscriptionBatches = policy.batches;

    if (this.connected) {
      const additions = this.subscriptions.filter(
        (symbol) => !previous.has(symbol),
      );
      const dynamic = this.subscriptionPolicy.validateAndBatch(additions);
      for (const batch of dynamic.batches) {
        this.transport.subscribe(batch);
      }
    }
  }

  onQuote(handler: (quote: MarketQuoteResult & { exchange: string }) => void) {
    this.handler = handler;
  }

  get providerSymbols() {
    return [...this.subscriptions];
  }

  get subscribeBatches() {
    return this.subscriptionBatches.map((batch) => [...batch]);
  }

  get isConnected() {
    return this.connected && this.transport.isConnected();
  }

  ingestRawTick(values: unknown[]) {
    const providerSymbol = String(values[0] ?? '').trim().toUpperCase();
    const exchange = this.exchangeByProviderSymbol.get(providerSymbol);
    this.handler?.(this.normalizer.fromArray(values, exchange));
  }
}
