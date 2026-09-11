import { Injectable, ServiceUnavailableException } from '@nestjs/common';

export type MarketNewsItem = {
  id: string;
  title: string;
  source: string;
  url: string;
  imageUrl: string | null;
  publishedAt: string;
};

@Injectable()
export class MarketNewsService {
  private cache: { expiresAt: number; items: MarketNewsItem[] } | null = null;
  private readonly defaultFeeds = [
    'https://nsearchives.nseindia.com/content/RSS/Online_announcements.xml',
    'https://www.sebi.gov.in/sebirss.xml',
    'https://news.google.com/rss/search?q=Indian%20stock%20market&hl=en-IN&gl=IN&ceid=IN:en',
  ];

  private get feedUrls() {
    const configured = (process.env.MARKET_NEWS_RSS_URLS || process.env.MARKET_NEWS_RSS_URL || '')
      .split(',').map((value) => value.trim()).filter(Boolean);
    return configured.length ? configured : this.defaultFeeds;
  }

  async latest(limit = 8) {
    const safeLimit = Math.min(Math.max(Math.trunc(limit) || 8, 1), 20);
    if (this.cache && this.cache.expiresAt > Date.now()) return this.cache.items.slice(0, safeLimit);
    try {
      const requests = this.feedUrls.map((feed) => this.fetchFeed(feed));
      if (process.env.MARKET_NEWS_PROVIDER !== 'rss') requests.push(this.fetchGdelt());
      const results = await Promise.allSettled(requests);
      const items = results.flatMap((result) => result.status === 'fulfilled' ? result.value : [])
        .filter((item, index, all) => all.findIndex((candidate) => candidate.url === item.url || candidate.title === item.title) === index)
        .sort((a, b) => Date.parse(b.publishedAt) - Date.parse(a.publishedAt))
        .slice(0, 50);
      if (!items.length) throw new Error('RSS contained no valid news');
      this.cache = { expiresAt: Date.now() + 300_000, items };
      return items.slice(0, safeLimit);
    } catch {
      if (this.cache?.items.length) return this.cache.items.slice(0, safeLimit);
      throw new ServiceUnavailableException('Market news is temporarily unavailable');
    }
  }

  private async fetchFeed(feed: string) {
    const url = new URL(feed);
    if (url.protocol !== 'https:') throw new Error('HTTPS RSS URL required');
    const response = await fetch(url, { signal: AbortSignal.timeout(7000), headers: { accept: 'application/rss+xml, application/xml;q=0.9', 'user-agent': 'IndiaTradingApp/1.0' } });
    if (!response.ok) throw new Error(`RSS responded ${response.status}`);
    const xml = await response.text();
    if (xml.length > 2_000_000) throw new Error('RSS response is too large');
    return [...xml.matchAll(/<item\b[\s\S]*?<\/item>/gi)]
      .map((match, index) => this.parseItem(match[0], index))
      .filter((item): item is MarketNewsItem => item !== null);
  }

  private async fetchGdelt(): Promise<MarketNewsItem[]> {
    const url = new URL(process.env.MARKET_NEWS_API_URL || 'https://api.gdeltproject.org/api/v2/doc/doc');
    if (url.protocol !== 'https:') throw new Error('HTTPS news API required');
    url.search = new URLSearchParams({query:'(Nifty OR Sensex OR "Indian stock market" OR "Bombay Stock Exchange") sourcelang:english', mode:'artlist',format:'json',maxrecords:'20',timespan:'3d',sort:'datedesc'}).toString();
    const response = await fetch(url, {signal:AbortSignal.timeout(5000)});
    if (!response.ok) throw new Error('News API unavailable');
    const json = await response.json() as {articles?: {url:string;title:string;domain:string;socialimage?:string;seendate:string}[]};
    return (Array.isArray(json.articles) ? json.articles : []).flatMap(article => {
      if (!article.title || /[\u3400-\u9fff]/.test(article.title) || !this.safeHttpUrl(article.url)) return [];
      const stamp = article.seendate?.replace(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/, '$1-$2-$3T$4:$5:$6Z');
      if (!stamp || !Number.isFinite(Date.parse(stamp))) return [];
      return [{id:article.url,title:article.title,source:article.domain || new URL(article.url).hostname,url:article.url,imageUrl:article.socialimage && this.safeHttpsUrl(article.socialimage) ? article.socialimage : null,publishedAt:new Date(stamp).toISOString()}];
    });
  }

  private parseItem(xml: string, index: number): MarketNewsItem | null {
    const title = this.text(xml, 'title');
    const link = this.text(xml, 'link');
    const published = this.text(xml, 'pubDate');
    if (!title || /[\u3400-\u9fff]/.test(title) || !this.safeHttpUrl(link)) return null;
    const source = this.text(xml, 'source') || new URL(link).hostname.replace(/^www\./, '');
    const imageCandidate = /<(?:media:content|enclosure)[^>]+url=["']([^"']+)["']/i.exec(xml)?.[1]
      || /<img[^>]+src=["']([^"']+)["']/i.exec(this.text(xml, 'description'))?.[1]
      || null;
    // Missing/invalid dates must not turn old announcements into breaking news.
    if (!published || !Number.isFinite(Date.parse(published))) return null;
    const publishedAt = new Date(published).toISOString();
    return { id: `${new URL(link).hostname}-${Date.parse(publishedAt)}-${index}`, title, source, url: link, imageUrl: imageCandidate && this.safeHttpsUrl(imageCandidate) ? imageCandidate : null, publishedAt };
  }

  private text(xml: string, tag: string) {
    const value = new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${tag}>`, 'i').exec(xml)?.[1] ?? '';
    return value.replace(/^<!\[CDATA\[|\]\]>$/g, '').replace(/<[^>]+>/g, ' ').replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/\s+/g, ' ').trim();
  }

  private safeHttpUrl(value: string) {
    try { return ['http:', 'https:'].includes(new URL(value).protocol); } catch { return false; }
  }

  private safeHttpsUrl(value: string) {
    try { return new URL(value).protocol === 'https:'; } catch { return false; }
  }
}
