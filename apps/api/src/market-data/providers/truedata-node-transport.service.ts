import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

type TrueDataFeed = {
  on: (event: string, handler: (payload: unknown[]) => void) => void;
  off?: (event: string, handler: (payload: unknown[]) => void) => void;
  removeListener?: (
    event: string,
    handler: (payload: unknown[]) => void,
  ) => void;
};

type TrueDataNodeModule = {
  rtConnect?: (
    user: string,
    password: string,
    symbols: string[],
    port: number,
    bidask?: number,
    heartbeat?: number,
    replay?: number,
    url?: string,
  ) => unknown;
  rtDisconnect?: () => unknown;
  rtSubscribe?: (symbols: string[]) => unknown;
  rtUnsubscribe?: (symbols: string[]) => unknown;
  isSocketConnected?: () => boolean;
  rtFeed?: TrueDataFeed;
};

@Injectable()
export class TrueDataNodeTransportService {
  private sdk?: TrueDataNodeModule;
  private tickHandler?: (payload: unknown[]) => void;

  constructor(private readonly config: ConfigService) {}

  connect(symbols: string[], onTick: (payload: unknown[]) => void) {
    const user = this.required('TRUEDATA_USER');
    const password = this.required('TRUEDATA_PASSWORD');
    const port = this.positiveInteger(
      this.config.get<string>('TRUEDATA_PORT'),
      8082,
    );
    const bidask = this.booleanFlag('TRUEDATA_BIDASK', true);
    const heartbeat = this.booleanFlag('TRUEDATA_HEARTBEAT', true);
    const replay = this.booleanFlag('TRUEDATA_REPLAY', false);
    const url = this.config.get<string>('TRUEDATA_URL')?.trim() || 'push';

    const sdk = this.loadSdk();
    if (typeof sdk.rtConnect !== 'function') {
      throw new Error('truedata-nodejs does not expose rtConnect()');
    }
    if (!sdk.rtFeed || typeof sdk.rtFeed.on !== 'function') {
      throw new Error('truedata-nodejs does not expose rtFeed');
    }

    this.detachTickHandler();
    this.sdk = sdk;
    this.tickHandler = onTick;
    sdk.rtFeed.on('tick', onTick);

    return sdk.rtConnect(
      user,
      password,
      symbols,
      port,
      bidask ? 1 : 0,
      heartbeat ? 1 : 0,
      replay ? 1 : 0,
      url,
    );
  }

  subscribe(symbols: string[]) {
    if (symbols.length === 0) return;
    if (!this.sdk || typeof this.sdk.rtSubscribe !== 'function') {
      throw new Error('TrueData transport is not connected');
    }
    return this.sdk.rtSubscribe(symbols);
  }

  unsubscribe(symbols: string[]) {
    if (symbols.length === 0) return;
    if (!this.sdk || typeof this.sdk.rtUnsubscribe !== 'function') {
      throw new Error('TrueData transport is not connected');
    }
    return this.sdk.rtUnsubscribe(symbols);
  }

  disconnect() {
    this.detachTickHandler();
    const sdk = this.sdk;
    this.sdk = undefined;
    if (sdk && typeof sdk.rtDisconnect === 'function') {
      return sdk.rtDisconnect();
    }
  }

  isConnected() {
    return this.sdk?.isSocketConnected?.() ?? false;
  }

  private detachTickHandler() {
    if (!this.sdk?.rtFeed || !this.tickHandler) return;
    if (typeof this.sdk.rtFeed.off === 'function') {
      this.sdk.rtFeed.off('tick', this.tickHandler);
    } else if (typeof this.sdk.rtFeed.removeListener === 'function') {
      this.sdk.rtFeed.removeListener('tick', this.tickHandler);
    }
    this.tickHandler = undefined;
  }

  private loadSdk(): TrueDataNodeModule {
    try {
      // Intentionally resolved at runtime so normal polling deployments do not
      // require the optional TrueData SDK unless streaming is enabled.
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      return require('truedata-nodejs') as TrueDataNodeModule;
    } catch {
      throw new Error(
        'Optional dependency truedata-nodejs is not installed. Install it before enabling TRUEDATA streaming.',
      );
    }
  }

  private required(key: string) {
    const value = this.config.get<string>(key)?.trim();
    if (!value) throw new Error(`${key} is required`);
    return value;
  }

  private booleanFlag(key: string, fallback: boolean) {
    const value = this.config.get<string>(key);
    if (value === undefined) return fallback;
    return value.trim().toLowerCase() === 'true';
  }

  private positiveInteger(value: string | undefined, fallback: number) {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
