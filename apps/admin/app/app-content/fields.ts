/**
 * Admin App Content field definitions (Phase 11A).
 * Stable API keys are retained even when UI labels change
 * (e.g. tab.holdings → label "Positions").
 */

export type FieldDef = {
  key: string;
  label: string;
  rows: number;
  title?: boolean;
  locale?: string;
};

export const homeBannerFields: FieldDef[] = [
  { key: "banner.title", label: "首页横幅标题", rows: 2 },
  { key: "banner.subtitle", label: "首页横幅副标题", rows: 2 },
  { key: "markets.banner.title", label: "行情页横幅标题", rows: 2 },
  { key: "markets.banner.subtitle", label: "行情页横幅副标题", rows: 2 },
  { key: "markets.loading", label: "行情加载提示", rows: 1 },
  { key: "markets.watchlist_error_title", label: "自选列表加载失败标题", rows: 1 },
  { key: "markets.watchlist_error_body", label: "自选列表加载失败说明", rows: 2 },
  { key: "markets.search_error_title", label: "行情搜索失败标题", rows: 1 },
  { key: "markets.search_error_body", label: "行情搜索失败说明", rows: 2 },
  { key: "markets.load_more", label: "加载更多按钮", rows: 1 },
  { key: "markets.load_more_retry", label: "加载更多重试按钮", rows: 1 },
  { key: "markets.refresh", label: "刷新行情按钮", rows: 1 },
];

export const homeCompanyFields: FieldDef[] = [
  { key: "company.section_title", label: "公司展示区标题", rows: 1 },
  { key: "company.video_cta", label: "公司视频按钮文案", rows: 1 },
  { key: "company.website_cta", label: "公司官网按钮文案", rows: 1 },
];

export const homeFundsFields: FieldDef[] = [
  { key: "funds.cta_label", label: "Add Funds 按钮标题", rows: 1 },
  { key: "funds.cta_subtitle", label: "Add Funds 按钮副标题", rows: 1 },
  { key: "funds.withdraw_cta_label", label: "Withdraw 按钮标题", rows: 1 },
  { key: "funds.withdraw_cta_subtitle", label: "Withdraw 按钮副标题", rows: 1 },
  { key: "funds.trade_cta_label", label: "Trade 按钮标题", rows: 1 },
  { key: "funds.trade_cta_subtitle", label: "Trade 按钮副标题", rows: 1 },
  { key: "funds.total_asset_label", label: "总资产文案", rows: 1 },
];

/** Deprecated / unused by current Flutter — kept in DB, hidden from primary form. */
export const homeLegacyFields: FieldDef[] = [
  {
    key: "funds.available_label",
    label: "[Legacy] 可用资金文案（当前客户端未使用）",
    rows: 1,
  },
];

export const homeNewsFields: FieldDef[] = [
  { key: "indices.section_title", label: "指数区标题", rows: 1 },
  { key: "view_all_cta", label: "「查看全部」按钮", rows: 1 },
  { key: "news.section_title", label: "市场新闻区标题", rows: 1 },
  { key: "news.empty", label: "市场新闻空状态", rows: 2 },
  { key: "news.page_empty_title", label: "市场新闻页空状态标题", rows: 1 },
  { key: "news.page_empty_body", label: "市场新闻页空状态说明", rows: 2 },
  { key: "news.refresh", label: "刷新新闻按钮提示", rows: 1 },
  { key: "news.refresh_error", label: "新闻刷新失败提示", rows: 2 },
];

export const homeProfileFields: FieldDef[] = [
  { key: "notifications.title", label: "通知页面标题", rows: 1 },
  { key: "notifications.loading", label: "通知加载提示", rows: 1 },
  { key: "notifications.load_error", label: "通知加载失败标题", rows: 1 },
  { key: "notifications.load_error_body", label: "通知加载失败说明", rows: 2 },
  { key: "notifications.empty_title", label: "无通知标题", rows: 1 },
  { key: "notifications.empty_body", label: "无通知说明", rows: 2 },
  { key: "notifications.recent", label: "最近更新标题", rows: 1 },
  { key: "notifications.caught_up", label: "全部已读提示", rows: 1 },
  { key: "notifications.unread_count", label: "未读数量模板（{count}）", rows: 1 },
  { key: "notifications.mark_read_error", label: "标记已读失败提示", rows: 2 },
  { key: "notifications.mark_all_error", label: "全部标记已读失败提示", rows: 2 },
  { key: "notifications.marking", label: "标记处理中辅助提示", rows: 1 },
  { key: "notifications.unread", label: "未读状态辅助提示", rows: 1 },
  { key: "profile.page_title", label: "个人中心页标题", rows: 1 },
  { key: "profile.section.overview", label: "概览分区标题", rows: 1 },
  { key: "profile.section.account", label: "Account 分区标题", rows: 1 },
  { key: "profile.section.funds", label: "Funds 分区标题", rows: 1 },
  { key: "profile.section.security", label: "Security 分区标题", rows: 1 },
  { key: "profile.section.preferences", label: "Preferences 分区标题", rows: 1 },
  {
    key: "profile.section.support",
    label: "Support & Education 分区标题",
    rows: 1,
  },
  { key: "profile.section.legal", label: "Legal 分区标题", rows: 1 },
  { key: "profile.metric.available", label: "概览 · Available Balance", rows: 1 },
  {
    key: "profile.metric.portfolio",
    label: "概览 · Product Holdings",
    rows: 1,
  },
  { key: "profile.metric.returns", label: "概览 · Total Returns", rows: 1 },
  { key: "profile.tile.help.title", label: "帮助入口标题", rows: 1 },
  { key: "profile.tile.help.subtitle", label: "帮助入口副标题", rows: 2 },
  { key: "profile.tile.insights.title", label: "Insights 入口标题", rows: 1 },
  {
    key: "profile.tile.insights.subtitle",
    label: "Insights 入口副标题",
    rows: 2,
  },
  { key: "profile.tile.about.title", label: "About 入口标题", rows: 1 },
  { key: "profile.tile.about.subtitle", label: "About 入口副标题", rows: 2 },
  { key: "profile.tile.risk.title", label: "风险披露入口标题", rows: 1 },
  { key: "profile.tile.terms.title", label: "服务条款入口标题", rows: 1 },
  { key: "profile.tile.privacy.title", label: "隐私政策入口标题", rows: 1 },
  { key: "profile.logout_label", label: "退出登录标题", rows: 1 },
  { key: "profile.logout_subtitle", label: "退出登录副标题", rows: 1 },
];

export const homeWithdrawFields: FieldDef[] = [
  { key: "withdraw.dialog_title", label: "提现弹窗标题", rows: 1 },
  { key: "withdraw.available_label", label: "可用资金标签", rows: 1 },
  {
    key: "withdraw.frozen_template",
    label: "冻结金额文案（可用 {amount}）",
    rows: 1,
  },
  { key: "withdraw.amount_label", label: "提现金额字段标签", rows: 1 },
  { key: "withdraw.min_hint", label: "最低提现提示", rows: 1 },
  { key: "withdraw.pin_label", label: "提现 PIN 字段标签", rows: 1 },
  { key: "withdraw.bank_section_title", label: "银行信息区标题", rows: 1 },
  { key: "withdraw.bank_picker_label", label: "银行账户下拉标签", rows: 1 },
  { key: "withdraw.holder_label", label: "户名标签", rows: 1 },
  { key: "withdraw.account_label", label: "账号标签", rows: 1 },
  { key: "withdraw.status_label", label: "银行状态标签", rows: 1 },
  { key: "withdraw.notice", label: "提现说明正文", rows: 4 },
  { key: "withdraw.records_title", label: "提现记录标题", rows: 1 },
  { key: "withdraw.cancel", label: "取消按钮", rows: 1 },
  { key: "withdraw.submit", label: "提交按钮", rows: 1 },
  { key: "withdraw.bank_incomplete", label: "银行信息不完整提示", rows: 2 },
  { key: "withdraw.submitting", label: "提交中提示", rows: 1 },
  { key: "withdraw.min_error", label: "低于最低金额错误", rows: 1 },
  {
    key: "withdraw.max_error_template",
    label: "超过可用余额错误（可用 {amount}）",
    rows: 1,
  },
  { key: "withdraw.bank_error", label: "未选完整银行账户错误", rows: 1 },
  { key: "withdraw.pin_error", label: "PIN 格式错误", rows: 1 },
];

export const homeFields: FieldDef[] = [
  ...homeBannerFields,
  ...homeCompanyFields,
  ...homeFundsFields,
  ...homeNewsFields,
  ...homeProfileFields,
  ...homeWithdrawFields,
];

export const depositFields: FieldDef[] = [
  { key: "page_title", label: "页面标题（AppBar）", rows: 1 },
  { key: "hero_title", label: "充值页主标题", rows: 1 },
  { key: "instructions", label: "充值说明正文", rows: 4 },
  { key: "cta_label", label: "联系客服按钮文案", rows: 1 },
  { key: "chat_preset", label: "充值页打开客服时的预填消息", rows: 2 },
  {
    key: "api_reject_message",
    label: "接口拒绝自助充值时的提示文案",
    rows: 3,
  },
  { key: "history_section_title", label: "入金历史区标题", rows: 1 },
  { key: "history_empty", label: "入金历史空状态", rows: 1 },
  { key: "terms_section_title", label: "条款区标题", rows: 1 },
  { key: "terms", label: "充值条款说明", rows: 5 },
];

export const supportFields: FieldDef[] = [
  { key: "fab_label", label: "侧边客服悬浮按钮文案", rows: 1 },
  { key: "header_title", label: "客服面板标题", rows: 1 },
  { key: "greeting", label: "客服欢迎语", rows: 3 },
  {
    key: "hours",
    label: "服务时间滚动提示（客服面板顶部公告，可横向滚动）",
    rows: 2,
  },
  { key: "quick_topics_label", label: "快捷主题区标题", rows: 1 },
  { key: "topic.deposit", label: "快捷主题 · 入金", rows: 1 },
  { key: "topic.trading", label: "快捷主题 · 交易", rows: 1 },
  { key: "topic.account", label: "快捷主题 · 账户", rows: 1 },
  { key: "composer_hint", label: "输入框提示文案（Web/桌面）", rows: 1 },
  { key: "chat_preset.help", label: "帮助入口预填消息", rows: 2 },
  { key: "chat_preset.deposit", label: "快捷主题「入金」预填消息", rows: 2 },
  {
    key: "salesmartly_script_url",
    label: "SaleSmartly Script URL（en/hi 共用，两端客服入口共用）",
    rows: 2,
  },
];

export const supportTagField = {
  key: "tags",
  label: "客服标签（逗号分隔）",
  locale: "zh",
  rows: 2,
} as const;

export const supportQuickReplies = [
  { key: "quick_reply.deposit", label: "快捷回复 · 入金", locale: "zh" },
  { key: "quick_reply.withdrawal", label: "快捷回复 · 提现", locale: "zh" },
  { key: "quick_reply.kyc", label: "快捷回复 · KYC", locale: "zh" },
  { key: "quick_reply.general", label: "快捷回复 · 通用", locale: "zh" },
] as const;

export const aboutFields = [
  { key: "company_name", label: "显示名称", rows: 1 },
  { key: "legal_name", label: "法律主体名称", rows: 2 },
  { key: "registered_address", label: "注册地址", rows: 3 },
  { key: "grievance_contact", label: "投诉/申诉联系方式", rows: 3 },
  {
    key: "app_version",
    label: "版本展示文案 / Marketing Version Label（非真实构建版本）",
    rows: 1,
  },
  { key: "summary", label: "About 简介", rows: 4 },
] as const;

export const insightIntroFields = [
  { key: "intro.title", label: "Insights 标题", rows: 2 },
  { key: "intro.body", label: "Insights 介绍", rows: 4 },
] as const;

export const insightArticleKeys = [
  "article.01",
  "article.02",
  "article.03",
  "article.04",
  "article.05",
  "article.06",
  "article.07",
  "article.08",
] as const;

export const tradingFields: FieldDef[] = [
  { key: "tab.trades", label: "Tab · Trades", rows: 1 },
  { key: "tab.institutional", label: "Tab · Institutional", rows: 1 },
  {
    key: "tab.holdings",
    // Stable legacy key retained for compatibility.
    label: "Tab · Positions（key: tab.holdings）",
    rows: 1,
  },
  { key: "tab.pending", label: "Tab · Pending", rows: 1 },
  { key: "tab.order_book", label: "Tab · Order Book", rows: 1 },
  { key: "tab.otc", label: "Tab · OTC", rows: 1 },
  { key: "tab.ipo", label: "Tab · IPO", rows: 1 },
  { key: "tab.history", label: "Tab · History", rows: 1 },
  { key: "tab.funds_ledger", label: "Tab · Funds Ledger", rows: 1 },
  {
    key: "tab.all",
    // Stable legacy key retained for compatibility.
    label: "产品筛选 · Overview（key: tab.all）",
    rows: 1,
  },
  { key: "tab.ins_stock", label: "产品筛选 · 涨停股", rows: 1 },
  { key: "shortcut.overview", label: "快捷入口 · Overview", rows: 1 },
  { key: "shortcut.orders", label: "快捷入口 · Orders", rows: 1 },
  { key: "institutional.empty_title", label: "涨停股空状态标题", rows: 2 },
  { key: "institutional.empty_subtitle", label: "涨停股空状态说明", rows: 3 },
  { key: "otc.empty_title", label: "OTC 空状态标题", rows: 2 },
  { key: "otc.empty_subtitle", label: "OTC 空状态说明", rows: 3 },
  {
    key: "ipo.confirm_template",
    label:
      "IPO 提交确认文案（仅展示；可用占位符 {current}/{max}，不改变真实限额/资格）",
    rows: 4,
  },
  { key: "ipo.empty_open_title", label: "IPO 开放列表空状态标题", rows: 2 },
  { key: "ipo.empty_open_subtitle", label: "IPO 开放列表空状态说明", rows: 2 },
  { key: "ipo.empty_title", label: "IPO 其他列表空状态标题", rows: 2 },
  { key: "ipo.empty_subtitle", label: "IPO 其他列表空状态说明", rows: 2 },
  { key: "portfolio.page_title", label: "组合页标题", rows: 1 },
  { key: "portfolio.page_subtitle", label: "组合页副标题", rows: 1 },
  { key: "portfolio.loading", label: "组合加载提示", rows: 1 },
  { key: "portfolio.load_error_title", label: "组合加载失败标题", rows: 1 },
  { key: "portfolio.recent_activity", label: "近期活动标题", rows: 1 },
  { key: "portfolio.view_details", label: "查看详情按钮", rows: 1 },
  { key: "portfolio.close", label: "关闭按钮", rows: 1 },
  { key: "portfolio.summary_heading", label: "投资摘要标题", rows: 1 },
  { key: "portfolio.allocation_heading", label: "资产配置标题", rows: 1 },
  { key: "portfolio.empty_title", label: "组合空状态标题", rows: 2 },
  { key: "portfolio.empty_subtitle", label: "组合空状态说明", rows: 2 },
  { key: "portfolio.explore_cta", label: "组合空状态按钮文案", rows: 1 },
  { key: "portfolio.detail.quantity", label: "持仓详情 · 数量", rows: 1 },
  { key: "portfolio.detail.available", label: "持仓详情 · 可用", rows: 1 },
  { key: "portfolio.detail.average_cost", label: "持仓详情 · 平均成本", rows: 1 },
  { key: "portfolio.detail.current_value", label: "持仓详情 · 当前价值", rows: 1 },
  { key: "portfolio.detail.unrealized_pnl", label: "持仓详情 · 未实现盈亏", rows: 1 },
  { key: "portfolio.detail.frozen", label: "持仓详情 · 冻结", rows: 1 },
  { key: "portfolio.detail.current_price", label: "持仓详情 · 当前价格", rows: 1 },
  { key: "portfolio.detail.invested", label: "持仓详情 · 已投入", rows: 1 },
  { key: "portfolio.detail.realized_pnl", label: "持仓详情 · 已实现盈亏", rows: 1 },
  { key: "portfolio.detail.day_pnl", label: "持仓详情 · 当日盈亏", rows: 1 },
  { key: "portfolio.detail.valuation_cost", label: "持仓详情 · 成本估值说明", rows: 2 },
  { key: "portfolio.detail.valuation_market", label: "持仓详情 · 市场估值说明", rows: 2 },
  { key: "state.data_unavailable", label: "交易数据不可用提示", rows: 2 },
  { key: "state.loading", label: "交易数据加载提示", rows: 2 },
  { key: "orders.clear_filters", label: "订单筛选 · 清除筛选", rows: 1 },
  { key: "orders.empty_title", label: "订单空状态标题", rows: 2 },
  { key: "orders.empty_message", label: "订单空状态说明", rows: 3 },
  { key: "action.buy", label: "交易操作 · 买入", rows: 1 },
  { key: "action.sell", label: "交易操作 · 卖出", rows: 1 },
  { key: "action.retry", label: "交易操作 · 重试", rows: 1 },
  { key: "holdings.empty_title", label: "Positions 空状态标题", rows: 2 },
  { key: "holdings.empty_subtitle", label: "Positions 空状态说明", rows: 2 },
  {
    key: "guide.institutional",
    label: "交易说明 · 涨停股",
    rows: 4,
    title: true,
  },
  { key: "guide.otc", label: "交易说明 · OTC", rows: 4, title: true },
  { key: "guide.ipo", label: "交易说明 · IPO", rows: 4, title: true },
];

export const tradingLegacyFields: FieldDef[] = [
  {
    key: "portfolio.value_label",
    label: "[Legacy] 组合总价值标签（当前客户端未使用）",
    rows: 1,
  },
];

export const tradingTabFields = tradingFields.filter(
  (field) => field.key.startsWith("tab.") || field.key.startsWith("shortcut."),
);
export const tradingEmptyFields = tradingFields.filter(
  (field) =>
    field.key.includes("empty") ||
    field.key === "ipo.confirm_template" ||
    field.key.startsWith("portfolio.") ||
    field.key.startsWith("holdings."),
);
export const tradingGuideFields = tradingFields.filter((field) =>
  field.key.startsWith("guide."),
);

/** Primary editable fields for bulk save (excludes legacy-only). */
export const tradingSaveFields: FieldDef[] = [
  ...tradingFields,
];
