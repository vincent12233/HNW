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
  private readonly configuredFeedUrl = process.env.MARKET_NEWS_RSS_URL?.trim();

  private get feedUrl() {
    if (this.configuredFeedUrl) return this.configuredFeedUrl;
    if (process.env.NODE_ENV === 'production') {
      throw new ServiceUnavailableException('Licensed market news feed is not configured');
    }
    return 'https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms';
  }

  async latest(limit = 8) {
    const safeLimit = Math.min(Math.max(Math.trunc(limit) || 8, 1), 20);
    if (this.cache && this.cache.expiresAt > Date.now()) return this.cache.items.slice(0, safeLimit);
    try {
      const url = new URL(this.feedUrl);
      if (url.protocol !== 'https:') throw new Error('HTTPS RSS URL required');
      const response = await fetch(url, { signal: AbortSignal.timeout(7000), headers: { accept: 'application/rss+xml, application/xml;q=0.9', 'user-agent': 'IndiaTradingApp/1.0' } });
      if (!response.ok) throw new Error(`RSS responded ${response.status}`);
      const xml = await response.text();
      if (xml.length > 2_000_000) throw new Error('RSS response is too large');
      const items = [...xml.matchAll(/<item\b[\s\S]*?<\/item>/gi)]
        .map((match, index) => this.parseItem(match[0], index))
        .filter((item): item is MarketNewsItem => item !== null)
        .sort((a, b) => Date.parse(b.publishedAt) - Date.parse(a.publishedAt))
        .slice(0, 20);
      if (!items.length) throw new Error('RSS contained no valid news');
      this.cache = { expiresAt: Date.now() + 5 * 60_000, items };
      return items.slice(0, safeLimit);
    } catch {
      if (this.cache?.items.length) return this.cache.items.slice(0, safeLimit);
      throw new ServiceUnavailableException('Market news is temporarily unavailable');
    }
  }

  private parseItem(xml: string, index: number): MarketNewsItem | null {
    const title = this.text(xml, 'title');
    const link = this.text(xml, 'link');
    const published = this.text(xml, 'pubDate');
    if (!title || !this.safeHttpUrl(link)) return null;
    const source = this.text(xml, 'source') || new URL(link).hostname.replace(/^www\./, '');
    const imageCandidate = /<(?:media:content|enclosure)[^>]+url=["']([^"']+)["']/i.exec(xml)?.[1]
      || /<img[^>]+src=["']([^"']+)["']/i.exec(this.text(xml, 'description'))?.[1]
      || null;
    const publishedAt = new Date(published).toString() === 'Invalid Date' ? new Date().toISOString() : new Date(published).toISOString();
    return { id: `${Date.parse(publishedAt)}-${index}`, title, source, url: link, imageUrl: imageCandidate && this.safeHttpsUrl(imageCandidate) ? imageCandidate : null, publishedAt };
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
