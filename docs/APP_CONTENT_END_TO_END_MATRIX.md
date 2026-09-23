# App Content End-to-End Matrix

> 2026-09-23 源码复核：所有通过 `AppText` / `tr` 呈现的静态 App 文案均可由 Home → Global App copy JSON 覆盖，英文和 Hindi 分开维护；页面级高频运营文案仍使用结构化字段。页面结构、主题、品牌资源、动态市场数据和服务端业务数据不属于文案配置。App Content 有 5 分钟内存缓存，保存不会主动推送所有在线客户端。

| Feature | Admin UI | Admin API | DB | Public API | Flutter Service | Flutter UI | Locale | Fallback | Audit | Status |
|---------|----------|-----------|----|------------|-----------------|------------|--------|----------|-------|--------|
| Home KV | `/app-content` Home | `/admin/app-content` | AppContentEntry | `/app-content` | AppContentService | Home banners/funds/news/profile/withdraw | en/hi | local strings | Yes | COMPLETE |
| Global UI copy | Home → Global App copy | `/admin/app-content` | AppContentEntry `HOME/ui.copy` | `/app-content` | AppLanguage + AppContentService | Login/KYC/account/security/common widgets | en/hi | local `tr` dictionary | Yes | COMPLETE |
| Deposit | Content · Deposit | same | AppContentEntry | `/app-content` | AppContentService | Deposit page | en/hi | local | Yes | COMPLETE |
| Support | Content · Support | same | AppContentEntry | `/app-content` (+ desk) | AppContentService | Client chat copy; desk internal only | en/hi (+ zh desk) | env script URL | Yes | COMPLETE |
| Trading copy | Content · Trading | same | AppContentEntry | `/app-content` | AppContentService | Trade/Portfolio labels/guides | en/hi | local | Yes | COMPLETE |
| Legal | Content · Legal | same | AppContentEntry | `/app-content` | AppContentService | Privacy/Terms pages | en/hi editor | local docs | Yes | IMPLEMENTED; translations require operator input |
| About | Content · About | same | AppContentEntry | `/app-content` | AppContentService | Profile About; build version separate | en/hi editor | AppConfig | Yes | COMPLETE |
| Insights | `/insights` | `/admin/insights` | InsightArticle | `/insights` | InsightArticlesService | Wealth Insights | en/hi | SUCCESS[] empty; failure error | Yes | COMPLETE |
| Announcements | `/announcements` | `/admin/announcements` | Announcement | `/announcements` | AnnouncementsService | Home single banner | en/hi | hide on fail | Yes | COMPLETE |
| App Settings | `/app-settings` | `/admin/app-settings` | AppClientSetting | `/app-settings` | AppClientSettingsService | Force/Maintenance/Optional | n/a | safe defaults | Yes | COMPLETE |
| Home Featured | `/featured-instruments` | placement PATCH | Instrument flags | `/market/instruments?featuredHome` | FeaturedInstrumentsService | Home Featured section | n/a | hide if empty | Yes | COMPLETE |
| Markets Featured | same | same | Instrument flags | `?featuredMarkets` | FeaturedInstrumentsService | Markets Featured section | n/a | hide if empty | Yes | COMPLETE |
| Company Showcase | `/company-showcase` | existing | CompanyShowcase | `/company-showcase` | MarketDataService | Home company card | n/a | hide | Yes | COMPLETE |
| Risk Disclosure | `/app-content` Legal | `/admin/app-content/bulk` | AppContentEntry | `/app-content` | AppContentService.riskDocument | LegalPage risk branch | en/hi editor | local risk sections | Yes | IMPLEMENTED; runtime not reverified |
| Store update URL | `/app-settings` updateUrl | `/admin/app-settings` | AppClientSetting | `/app-settings` | AppClientSettings.validUpdateUri | Update gate | platform-specific | invalid/missing URL handled | Yes | IMPLEMENTED; runtime not reverified |

---

*Generated for Phase 13 completion.*
