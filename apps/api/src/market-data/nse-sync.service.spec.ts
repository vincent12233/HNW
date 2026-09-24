import { ConfigService } from '@nestjs/config';
import { NseSyncService } from './nse-sync.service';

describe('NseSyncService polling selection', () => {
  function createService(batchSize = '2') {
    const prisma = {
      instrument: {
        findMany: jest.fn(),
      },
    };
    const provider = {
      providerName: 'TEST',
      getQuote: jest.fn(),
    };
    const ingestion = {
      ingest: jest.fn(),
    };
    const health = {
      getStatus: jest.fn().mockReturnValue({ stale: true }),
    };
    const config = {
      get: jest.fn((key: string) => {
        if (key === 'MARKET_DATA_POLL_BATCH_SIZE') return batchSize;
        return undefined;
      }),
    } as unknown as ConfigService;

    return {
      service: new NseSyncService(
        config,
        prisma as never,
        provider as never,
        ingestion as never,
      ),
      prisma,
      provider,
      ingestion,
      health,
    };
  }

  const candidate = (
    symbol: string,
    options: {
      quoteAt?: Date | null;
      position?: boolean;
      order?: boolean;
      category?: string | null;
    } = {},
  ) => ({
    symbol,
    exchange: 'NSE',
    category: options.category ?? null,
    quote: options.quoteAt ? { asOf: options.quoteAt } : null,
    positions: options.position ? [{ id: `position-${symbol}` }] : [],
    orders: options.order ? [{ id: `order-${symbol}` }] : [],
  });

  it('prioritizes institutional/OTC/IPO catalog symbols before ordinary symbols', () => {
    const { service } = createService('2');
    const batch = service.selectPollingBatch([
      candidate('REGULAR', { quoteAt: new Date('2026-08-12T01:00:00Z') }),
      candidate('INST', {
        quoteAt: new Date('2026-08-12T03:00:00Z'),
        category: 'INSTITUTIONAL',
      }),
      candidate('OTC1', {
        quoteAt: new Date('2026-08-12T02:00:00Z'),
        category: 'OTC',
      }),
    ]);
    expect(batch.map((item) => item.symbol)).toEqual(['OTC1', 'INST']);
  });

  it('prioritizes holdings and active-order symbols before ordinary symbols', () => {
    const { service } = createService('2');
    const batch = service.selectPollingBatch([
      candidate('REGULAR', { quoteAt: new Date('2026-08-12T01:00:00Z') }),
      candidate('HOLDING', {
        quoteAt: new Date('2026-08-12T03:00:00Z'),
        position: true,
      }),
      candidate('ORDER', {
        quoteAt: new Date('2026-08-12T02:00:00Z'),
        order: true,
      }),
    ]);

    expect(batch.map((item) => item.symbol)).toEqual(['ORDER', 'HOLDING']);
  });

  it('respects the configured batch size', () => {
    const { service } = createService('3');
    const batch = service.selectPollingBatch([
      candidate('A'),
      candidate('B'),
      candidate('C'),
      candidate('D'),
      candidate('E'),
    ]);

    expect(batch).toHaveLength(3);
  });

  it('rotates ordinary symbols by least recent polling attempt', async () => {
    const { service, prisma, provider, ingestion } = createService('2');
    const instruments = [
      candidate('A'),
      candidate('B'),
      candidate('C'),
      candidate('D'),
    ];
    prisma.instrument.findMany.mockResolvedValue(instruments);
    provider.getQuote.mockImplementation((symbol: string) =>
      Promise.resolve({
        symbol,
        price: 100,
        change: 0,
        volume: 0,
        previousClose: 100,
        openPrice: 100,
        highPrice: 100,
        lowPrice: 100,
        bidPrice: 100,
        askPrice: 100,
        source: 'TEST',
        updatedAt: new Date(),
      }),
    );
    ingestion.ingest.mockResolvedValue(undefined);

    await (service as unknown as { syncStocks(): Promise<void> }).syncStocks();
    await (service as unknown as { syncStocks(): Promise<void> }).syncStocks();

    expect(provider.getQuote.mock.calls.map((call) => call[0])).toEqual([
      'A',
      'B',
      'C',
      'D',
    ]);
  });

  it('syncs the four home indices with their actual exchanges', async () => {
    const { service, provider, ingestion } = createService();
    provider.getQuote.mockImplementation((symbol: string) =>
      Promise.resolve({ symbol }),
    );
    ingestion.ingest.mockResolvedValue(undefined);

    await (
      service as unknown as { syncIndices(): Promise<void> }
    ).syncIndices();

    expect(provider.getQuote.mock.calls).toEqual([
      ['NIFTY50', 'NSE'],
      ['SENSEX', 'BSE'],
      ['BANKNIFTY', 'NSE'],
      ['INDIAVIX', 'NSE'],
    ]);
    expect(ingestion.ingest.mock.calls).toEqual([
      ['NSE', { symbol: 'NIFTY50' }, 'INDEX'],
      ['BSE', { symbol: 'SENSEX' }, 'INDEX'],
      ['NSE', { symbol: 'BANKNIFTY' }, 'INDEX'],
      ['NSE', { symbol: 'INDIAVIX' }, 'INDEX'],
    ]);
  });
});
