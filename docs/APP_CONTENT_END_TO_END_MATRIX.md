# App Content End-to-End Matrix

| Feature | Admin UI | Admin API | DB | Public API | Flutter Service | Flutter UI | Locale | Fallback | Audit | Status |
|---------|----------|-----------|----|------------|-----------------|------------|--------|----------|-------|--------|
| Home KV | `/app-content` Home | `/admin/app-content` | AppContentEntry | `/app-content` | AppContentService | Home banners/funds/news/profile/withdraw | en/hi | local strings | Yes | COMPLETE |
| Deposit | Content · Deposit | same | AppContentEntry | `/app-content` | AppContentService | Deposit page | en/hi | local | Yes | COMPLETE |
| Support | Content · Support | same | AppContentEntry | `/app-content` (+ desk) | AppContentService | Client chat copy; desk internal only | en/hi (+ zh desk) | env script URL | Yes | COMPLETE |
| Trading copy | Content · Trading | same | AppContentEntry | `/app-content` | AppContentService | Trade/Portfolio labels/guides | en/hi | local | Yes | COMPLETE |
| Legal | Content · Legal | same | AppContentEntry | `/app-content` | AppContentService | Privacy/Terms pages | en (hi gap) | local docs | Yes | PARTIAL |
| About | Content · About | same | AppContentEntry | `/app-content` | AppContentService | Profile About; build version separate | en | AppConfig | Yes | COMPLETE |
| Insights | `/insights` + Legacy KV | `/admin/insights` | InsightArticle (+ KV) | `/insights` | InsightArticlesService | Wealth Insights | en/hi | SUCCESS[] empty; FAIL→KV→local | Yes | COMPLETE |
| Announcements | `/announcements` | `/admin/announcements` | Announcement | `/announcements` | AnnouncementsService | Home single banner | en/hi | hide on fail | Yes | COMPLETE |
| App Settings | `/app-settings` | `/admin/app-settings` | AppClientSetting | `/app-settings` | AppClientSettingsService | Force/Maintenance/Optional | n/a | safe defaults | Yes | COMPLETE |
| Home Featured | `/featured-instruments` | placement PATCH | Instrument flags | `/market/instruments?featuredHome` | FeaturedInstrumentsService | Home Featured section | n/a | hide if empty | Yes | COMPLETE |
| Markets Featured | same | same | Instrument flags | `?featuredMarkets` | FeaturedInstrumentsService | Markets Featured section | n/a | hide if empty | Yes | COMPLETE |
| Company Showcase | `/company-showcase` | existing | CompanyShowcase | `/company-showcase` | MarketDataService | Home company card | n/a | hide | Yes | COMPLETE |
| Risk Disclosure | — | — | — | — | — | — | — | — | — | DEFERRED |
| Store update URL | — | — | supportUrl only | — | open supportUrl | Force Update page | — | Retry | — | PARTIAL |

---

*Generated for Phase 13 completion.*
