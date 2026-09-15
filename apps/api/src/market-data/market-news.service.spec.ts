import { MarketNewsService } from './market-news.service';

describe('Free news provider', () => {
  it('does not invent publication times for undated announcements', () => {
    const service = new MarketNewsService() as any;
    expect(
      service.parseItem(
        '<item><title>Old notice</title><link>https://example.com/old</link></item>',
        0,
      ),
    ).toBeNull();
    expect(
      service.parseItem(
        '<item><title>Old notice</title><link>https://example.com/old</link><pubDate>invalid</pubDate></item>',
        0,
      ),
    ).toBeNull();
  });
  afterEach(() => jest.restoreAllMocks());
  it('maps English headlines and filters unsafe links and Chinese titles', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({
        articles: [
          {
            url: 'https://example.com/market',
            title: 'Sensex market update',
            domain: 'example.com',
            seendate: '20260910T120000Z',
            socialimage: 'https://example.com/image.png',
          },
          {
            url: 'javascript:alert(1)',
            title: 'Unsafe',
            seendate: '20260910T120000Z',
          },
          {
            url: 'https://example.com/zh',
            title: '中文新闻',
            seendate: '20260910T120000Z',
          },
        ],
      }),
    } as Response);
    const rows = await (new MarketNewsService() as any).fetchGdelt();
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      title: 'Sensex market update',
      publishedAt: '2026-09-10T12:00:00.000Z',
    });
  });
  it('keeps RSS usable when GDELT is unavailable and caches the response', async () => {
    const service = new MarketNewsService();
    const feed = jest
      .spyOn(service as any, 'fetchFeed')
      .mockResolvedValue([
        {
          id: '1',
          title: 'Market update',
          source: 'test',
          url: 'https://example.com',
          imageUrl: null,
          publishedAt: '2026-09-10T12:00:00Z',
        },
      ]);
    jest
      .spyOn(service as any, 'fetchGdelt')
      .mockRejectedValue(new Error('timeout'));
    expect(await service.latest()).toHaveLength(1);
    const calls = feed.mock.calls.length;
    await service.latest();
    expect(feed).toHaveBeenCalledTimes(calls);
  });
});
