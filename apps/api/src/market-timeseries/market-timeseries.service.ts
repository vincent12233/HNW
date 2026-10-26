import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import pg from 'pg';
import {
  recordOperationalCounter,
  setOperationalGauge,
} from '../observability/metrics';
import {
  CandleInterval,
  MarketCandle,
  MarketTick,
} from './market-timeseries.interface';

const INTERVALS: Record<CandleInterval, string> = {
  '1m': '1 minute',
  '5m': '5 minutes',
  '15m': '15 minutes',
  '1h': '1 hour',
  '1d': '1 day',
};

@Injectable()
export class MarketTimeseriesService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MarketTimeseriesService.name);
  private readonly queue: MarketTick[] = [];
  private pool?: pg.Pool;
  private timer?: NodeJS.Timeout;
  private flushing = false;

  constructor(private readonly config: ConfigService) {}

  onModuleInit(): void {
    const url = this.config.get<string>('TIMESERIES_DATABASE_URL')?.trim();
    if (!url) return;
    this.pool = new pg.Pool({
      connectionString: url,
      max: 4,
      connectionTimeoutMillis: 3000,
    });
    this.timer = setInterval(() => void this.flush(), 500);
    this.timer.unref();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearInterval(this.timer);
    await this.flush();
    await this.pool?.end();
  }

  appendTick(tick: MarketTick): void {
    if (!this.pool) return;
    if (this.queue.length >= 10_000) {
      this.queue.shift();
      recordOperationalCounter('timeseries_ticks_dropped');
    }
    this.queue.push(tick);
    setOperationalGauge('timeseries_buffer_depth', this.queue.length);
  }

  async getCandles(
    instrumentId: string,
    interval: CandleInterval,
    from: Date,
    to: Date,
  ): Promise<MarketCandle[]> {
    if (!this.pool) return [];
    const result = await this.pool.query<MarketCandle>(
      `SELECT time_bucket($1::interval, source_timestamp, 'Asia/Kolkata') AS bucket,
        first(price, source_timestamp)::float8 AS open, max(price)::float8 AS high,
        min(price)::float8 AS low, last(price, source_timestamp)::float8 AS close,
        max(volume)::float8 AS volume
       FROM market_ticks WHERE instrument_id = $2 AND source_timestamp >= $3 AND source_timestamp < $4
       GROUP BY bucket ORDER BY bucket`,
      [INTERVALS[interval], instrumentId, from, to],
    );
    return result.rows;
  }

  private async flush(): Promise<void> {
    if (!this.pool || this.flushing || this.queue.length === 0) return;
    this.flushing = true;
    const batch = this.queue.splice(0, 250);
    try {
      const values: unknown[] = [];
      const rows = batch.map((tick, index) => {
        const offset = index * 9;
        values.push(
          tick.instrumentId,
          tick.exchange,
          tick.symbol,
          tick.sequence,
          tick.price,
          tick.volume,
          tick.sourceTimestamp,
          tick.receivedAt,
          tick.quality,
        );
        return `(${Array.from({ length: 9 }, (_, i) => `$${offset + i + 1}`).join(',')})`;
      });
      await this.pool.query(
        `INSERT INTO market_ticks
          (instrument_id, exchange, symbol, sequence, price, volume, source_timestamp, received_at, quality)
         VALUES ${rows.join(',')} ON CONFLICT DO NOTHING`,
        values,
      );
      recordOperationalCounter('timeseries_ticks_written', batch.length);
    } catch (error: unknown) {
      this.queue.unshift(...batch);
      recordOperationalCounter('timeseries_write_failures');
      this.logger.warn(
        `Timeseries write deferred: ${error instanceof Error ? error.message : String(error)}`,
      );
    } finally {
      this.flushing = false;
      setOperationalGauge('timeseries_buffer_depth', this.queue.length);
    }
  }
}
