# App Content End-to-End Matrix

> 2026-09-22 源码复核：本矩阵描述已实现的内容链路，不代表全 App 可视化编辑，也不代表生产环境已联调验收。页面结构、主题颜色、品牌资源、部分按钮/表单/校验文案仍由 Flutter 代码维护。行情新闻由 RSS 提供，不能等同于后台洞察文章。Legal/About 已增加独立 English/Hindi 编辑入口，切换时提示未保存修改；实际译文仍需运营填写；App Content 有 5 分钟内存缓存，保存不会主动推送所有在线客户端。

| Feature | Admin UI | Admin API | DB | Public API | Flutter Service | Flutter UI | Locale | Fallback | Audit | Status |
|---------|----------|-----------|----|------------|-----------------|------------|--------|----------|-------|--------|
| Home KV | `/app-content` Home | `/admin/app-content` | AppContentEntry | `/app-content` | AppContentService | Home banners/funds/news/profile/withdraw | en/hi | local strings | Yes | COMPLETE |
| Deposit | Content · Deposit | same | AppContentEntry | `/app-content` | AppContentService | Deposit page | en/hi | local | Yes | COMPLETE |
| Support | Content · Support | same | AppContentEntry | `/app-content` (+ desk) | AppContentService | Client chat copy; desk internal only | en/hi (+ zh desk) | env script URL | Yes | COMPLETE |
| Trading copy | Content · Trading | same | AppContentEntry | `/app-content` | AppContentService | Trade/Portfolio labels/guides | en/hi | local | Yes | COMPLETE |
| Legal | Content · Legal | same | AppContentEntry | `/app-content` | AppContentService | Privacy/Terms pages | en/hi editor | local docs | Yes | IMPLEMENTED; translations require operator input |
| About | Content · About | same | AppContentEntry | `/app-content` | AppContentService | Profile About; build version separate | en/hi editor | AppConfig | Yes | COMPLETE |
| Insights | `/insights` + Legacy KV | `/admin/insights` | InsightArticle (+ KV) | `/insights` | InsightArticlesService | Wealth Insights | en/hi | SUCCESS[] empty; FAIL→KV→local | Yes | COMPLETE |
| Announcements | `/announcements` | `/admin/announcements` | Announcement | `/announcements` | AnnouncementsService | Home single banner | en/hi | hide on fail | Yes | COMPLETE |
| App Settings | `/app-settings` | `/admin/app-settings` | AppClientSetting | `/app-settings` | AppClientSettingsService | Force/Maintenance/Optional | n/a | safe defaults | Yes | COMPLETE |
| Home Featured | `/featured-instruments` | placement PATCH | Instrument flags | `/market/instruments?featuredHome` | FeaturedInstrumentsService | Home Featured section | n/a | hide if empty | Yes | COMPLETE |
| Markets Featured | same | same | Instrument flags | `?featuredMarkets` | FeaturedInstrumentsService | Markets Featured section | n/a | hide if empty | Yes | COMPLETE |
| Company Showcase | `/company-showcase` | existing | CompanyShowcase | `/company-showcase` | MarketDataService | Home company card | n/a | hide | Yes | COMPLETE |
| Risk Disclosure | `/app-content` Legal | `/admin/app-content/bulk` | AppContentEntry | `/app-content` | AppContentService.riskDocument | LegalPage risk branch | en/hi editor | local risk sections | Yes | IMPLEMENTED; runtime not reverified |
| Store update URL | `/app-settings` updateUrl | `/admin/app-settings` | AppClientSetting | `/app-settings` | AppClientSettings.validUpdateUri | Update gate | platform-specific | invalid/missing URL handled | Yes | IMPLEMENTED; runtime not reverified |

---

*Generated for Phase 13 completion.*
