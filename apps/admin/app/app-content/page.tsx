"use client";

import {
  BookOutlined,
  CustomerServiceOutlined,
  DollarOutlined,
  FileProtectOutlined,
  HomeOutlined,
  InfoCircleOutlined,
  ReloadOutlined,
  SaveOutlined,
  StockOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Collapse,
  Divider,
  Form,
  Input,
  Select,
  Space,
  Tabs,
  Typography,
  message,
} from "antd";
import Link from "next/link";
import { useEffect, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;
const { TextArea } = Input;

type FieldDef = {
  key: string;
  label: string;
  rows: number;
  title?: boolean;
  locale?: string;
};

function FieldGroup({
  title,
  hint,
  fields,
}: {
  title: string;
  hint?: string;
  fields: ReadonlyArray<FieldDef>;
}) {
  return (
    <Collapse
      defaultActiveKey={[title]}
      style={{ marginBottom: 16 }}
      items={[
        {
          key: title,
          label: <Text strong>{title}</Text>,
          children: (
            <>
              {hint ? (
                <Paragraph type="secondary" style={{ marginTop: 0 }}>
                  {hint}
                </Paragraph>
              ) : null}
              {fields.map((field) => (
                <div key={field.key}>
                  {"title" in field && field.title ? (
                    <Form.Item
                      name={`${field.key}__title`}
                      label={`${field.label} · 标题`}
                    >
                      <Input />
                    </Form.Item>
                  ) : null}
                  <Form.Item
                    name={field.key}
                    label={
                      "title" in field && field.title
                        ? `${field.label} · 正文`
                        : field.label
                    }
                    rules={[{ required: true, message: "请填写内容" }]}
                  >
                    <TextArea rows={field.rows} />
                  </Form.Item>
                </div>
              ))}
            </>
          ),
        },
      ]}
    />
  );
}

type ContentEntry = {
  id: string;
  module: "HOME" | "DEPOSIT" | "SUPPORT" | "TRADING" | "LEGAL" | "ABOUT" | "INSIGHTS";
  key: string;
  title?: string | null;
  body: string;
  locale: string;
  isActive: boolean;
  sortOrder: number;
};


const homeBannerFields: FieldDef[] = [
  { key: "banner.title", label: "首页横幅标题", rows: 2 },
  { key: "banner.subtitle", label: "首页横幅副标题", rows: 2 },
  { key: "markets.banner.title", label: "行情页横幅标题", rows: 2 },
  { key: "markets.banner.subtitle", label: "行情页横幅副标题", rows: 2 },
];

const homeCompanyFields: FieldDef[] = [
  { key: "company.section_title", label: "公司展示区标题", rows: 1 },
  { key: "company.video_cta", label: "公司视频按钮文案", rows: 1 },
  { key: "company.website_cta", label: "公司官网按钮文案", rows: 1 },
];

const homeFundsFields: FieldDef[] = [
  { key: "funds.cta_label", label: "Add Funds 按钮标题", rows: 1 },
  { key: "funds.cta_subtitle", label: "Add Funds 按钮副标题", rows: 1 },
  { key: "funds.withdraw_cta_label", label: "Withdraw 按钮标题", rows: 1 },
  { key: "funds.withdraw_cta_subtitle", label: "Withdraw 按钮副标题", rows: 1 },
  { key: "funds.total_asset_label", label: "总资产文案", rows: 1 },
  { key: "funds.available_label", label: "可用资金文案", rows: 1 },
];

const homeNewsFields: FieldDef[] = [
  { key: "indices.section_title", label: "指数区标题", rows: 1 },
  { key: "view_all_cta", label: "「查看全部」按钮", rows: 1 },
  { key: "news.section_title", label: "市场新闻区标题", rows: 1 },
  { key: "news.empty", label: "市场新闻空状态", rows: 2 },
];

const homeProfileFields: FieldDef[] = [
  { key: "profile.page_title", label: "个人中心页标题", rows: 1 },
  { key: "profile.section.overview", label: "概览分区标题", rows: 1 },
  { key: "profile.section.security", label: "账户安全分区标题", rows: 1 },
  { key: "profile.section.preferences", label: "偏好设置分区标题", rows: 1 },
  { key: "profile.section.support", label: "支持与更多分区标题", rows: 1 },
  { key: "profile.metric.available", label: "概览 · 可用余额", rows: 1 },
  { key: "profile.metric.portfolio", label: "概览 · 总组合", rows: 1 },
  { key: "profile.metric.returns", label: "概览 · 总收益", rows: 1 },
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
  { key: "profile.tile.terms.title", label: "服务条款入口标题", rows: 1 },
  { key: "profile.tile.privacy.title", label: "隐私政策入口标题", rows: 1 },
  { key: "profile.logout_label", label: "退出登录标题", rows: 1 },
  { key: "profile.logout_subtitle", label: "退出登录副标题", rows: 1 },
];

const homeWithdrawFields: FieldDef[] = [
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

const homeFields: FieldDef[] = [
  ...homeBannerFields,
  ...homeCompanyFields,
  ...homeFundsFields,
  ...homeNewsFields,
  ...homeProfileFields,
  ...homeWithdrawFields,
];

const depositFields: FieldDef[] = [
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

const supportFields: FieldDef[] = [
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
  { key: "salesmartly_script_url", label: "SaleSmartly Script URL", rows: 2 },
];

const supportTagField = {
  key: "tags",
  label: "客服标签（逗号分隔）",
  locale: "zh",
  rows: 2,
} as const;

const aboutFields = [
  { key: "company_name", label: "显示名称", rows: 1 },
  { key: "legal_name", label: "法律主体名称", rows: 2 },
  { key: "registered_address", label: "注册地址", rows: 3 },
  { key: "grievance_contact", label: "投诉/申诉联系方式", rows: 3 },
  { key: "app_version", label: "版本文案", rows: 1 },
  { key: "summary", label: "About 简介", rows: 4 },
] as const;

const insightIntroFields = [
  { key: "intro.title", label: "Insights 标题", rows: 2 },
  { key: "intro.body", label: "Insights 介绍", rows: 4 },
] as const;

const insightArticleKeys = [
  "article.01",
  "article.02",
  "article.03",
  "article.04",
  "article.05",
  "article.06",
  "article.07",
  "article.08",
] as const;

const supportQuickReplies = [
  { key: "quick_reply.deposit", label: "快捷回复 · 入金", locale: "zh" },
  { key: "quick_reply.withdrawal", label: "快捷回复 · 提现", locale: "zh" },
  { key: "quick_reply.kyc", label: "快捷回复 · KYC", locale: "zh" },
  { key: "quick_reply.general", label: "快捷回复 · 通用", locale: "zh" },
] as const;

const tradingFields: FieldDef[] = [
  { key: "tab.trades", label: "Tab · Trades", rows: 1 },
  { key: "tab.institutional", label: "Tab · Institutional", rows: 1 },
  { key: "tab.holdings", label: "Tab · Holdings", rows: 1 },
  { key: "tab.pending", label: "Tab · Pending", rows: 1 },
  { key: "tab.order_book", label: "Tab · Order Book", rows: 1 },
  { key: "tab.otc", label: "Tab · OTC", rows: 1 },
  { key: "tab.ipo", label: "Tab · IPO", rows: 1 },
  { key: "tab.history", label: "Tab · History", rows: 1 },
  { key: "tab.funds_ledger", label: "Tab · Funds Ledger", rows: 1 },
  { key: "tab.all", label: "产品筛选 · All", rows: 1 },
  { key: "tab.ins_stock", label: "产品筛选 · 涨停股", rows: 1 },
  { key: "shortcut.orders", label: "快捷入口 · Orders", rows: 1 },
  { key: "institutional.empty_title", label: "涨停股空状态标题", rows: 2 },
  { key: "institutional.empty_subtitle", label: "涨停股空状态说明", rows: 3 },
  { key: "otc.empty_title", label: "OTC 空状态标题", rows: 2 },
  { key: "otc.empty_subtitle", label: "OTC 空状态说明", rows: 3 },
  {
    key: "ipo.confirm_template",
    label: "IPO 提交确认文案（可用 {current}/{max}）",
    rows: 4,
  },
  { key: "ipo.empty_open_title", label: "IPO 开放列表空状态标题", rows: 2 },
  { key: "ipo.empty_open_subtitle", label: "IPO 开放列表空状态说明", rows: 2 },
  { key: "ipo.empty_title", label: "IPO 其他列表空状态标题", rows: 2 },
  { key: "ipo.empty_subtitle", label: "IPO 其他列表空状态说明", rows: 2 },
  { key: "portfolio.page_title", label: "组合页标题", rows: 1 },
  { key: "portfolio.value_label", label: "组合总价值标签", rows: 1 },
  { key: "portfolio.summary_heading", label: "投资摘要标题", rows: 1 },
  { key: "portfolio.allocation_heading", label: "资产配置标题", rows: 1 },
  { key: "portfolio.empty_title", label: "组合空状态标题", rows: 2 },
  { key: "portfolio.empty_subtitle", label: "组合空状态说明", rows: 2 },
  { key: "portfolio.explore_cta", label: "组合空状态按钮文案", rows: 1 },
  { key: "holdings.empty_title", label: "持仓空状态标题", rows: 2 },
  { key: "holdings.empty_subtitle", label: "持仓空状态说明", rows: 2 },
  {
    key: "guide.institutional",
    label: "交易说明 · 涨停股",
    rows: 4,
    title: true,
  },
  { key: "guide.otc", label: "交易说明 · OTC", rows: 4, title: true },
  { key: "guide.ipo", label: "交易说明 · IPO", rows: 4, title: true },
];

const tradingTabFields = tradingFields.filter(
  (field) => field.key.startsWith("tab.") || field.key.startsWith("shortcut."),
);
const tradingEmptyFields = tradingFields.filter(
  (field) =>
    field.key.includes("empty") ||
    field.key === "ipo.confirm_template" ||
    field.key.startsWith("portfolio.") ||
    field.key.startsWith("holdings."),
);
const tradingGuideFields = tradingFields.filter((field) =>
  field.key.startsWith("guide."),
);

function apiError(error: unknown, fallback: string) {
  const value = (error as { response?: { data?: { message?: unknown } } })
    ?.response?.data?.message;
  if (Array.isArray(value)) return value.map(String).join("，");
  return value == null ? fallback : String(value);
}

function entryValue(
  entries: ContentEntry[],
  module: ContentEntry["module"],
  key: string,
  locale = "en",
) {
  return (
    entries.find(
      (item) =>
        item.module === module && item.key === key && item.locale === locale,
    )?.body ?? ""
  );
}

function entryTitle(
  entries: ContentEntry[],
  module: ContentEntry["module"],
  key: string,
  locale = "en",
) {
  return (
    entries.find(
      (item) =>
        item.module === module && item.key === key && item.locale === locale,
    )?.title ?? ""
  );
}

export default function AppOpsContentPage() {
  const [entries, setEntries] = useState<ContentEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [homeForm] = Form.useForm();
  const [depositForm] = Form.useForm();
  const [supportForm] = Form.useForm();
  const [tradingForm] = Form.useForm();
  const [aboutForm] = Form.useForm();
  const [legalForm] = Form.useForm();
  const [insightsForm] = Form.useForm();
  const [opsLocale, setOpsLocale] = useState<"en" | "hi">("en");
  const [insightsLocale, setInsightsLocale] = useState<"en" | "hi">("en");

  async function loadAll() {
    setLoading(true);
    setError("");
    try {
      const contentResponse = await api.get<ContentEntry[]>("/admin/app-content");
      const nextEntries = Array.isArray(contentResponse.data)
        ? contentResponse.data
        : [];
      setEntries(nextEntries);
      applyOpsForms(nextEntries, opsLocale);
      aboutForm.setFieldsValue(
        Object.fromEntries(
          aboutFields.map((field) => [
            field.key,
            entryValue(nextEntries, "ABOUT", field.key),
          ]),
        ),
      );
      legalForm.setFieldsValue({
        "privacy.document": entryValue(nextEntries, "LEGAL", "privacy.document"),
        "terms.document": entryValue(nextEntries, "LEGAL", "terms.document"),
        "privacy.document__title": entryTitle(
          nextEntries,
          "LEGAL",
          "privacy.document",
        ),
        "terms.document__title": entryTitle(
          nextEntries,
          "LEGAL",
          "terms.document",
        ),
      });
      applyInsightsForm(nextEntries, insightsLocale);
    } catch (requestError: unknown) {
      setError(apiError(requestError, "运营配置加载失败"));
    } finally {
      setLoading(false);
    }
  }

  function applyOpsForms(nextEntries: ContentEntry[], locale: "en" | "hi") {
    homeForm.setFieldsValue(
      Object.fromEntries(
        homeFields.map((field) => [
          field.key,
          entryValue(nextEntries, "HOME", field.key, locale),
        ]),
      ),
    );
    depositForm.setFieldsValue(
      Object.fromEntries(
        depositFields.map((field) => [
          field.key,
          entryValue(nextEntries, "DEPOSIT", field.key, locale),
        ]),
      ),
    );
    supportForm.setFieldsValue({
      ...Object.fromEntries(
        supportFields.map((field) => [
          field.key,
          entryValue(nextEntries, "SUPPORT", field.key, locale),
        ]),
      ),
      [supportTagField.key]: entryValue(
        nextEntries,
        "SUPPORT",
        supportTagField.key,
        supportTagField.locale,
      ),
      ...Object.fromEntries(
        supportQuickReplies.map((field) => [
          field.key,
          entryValue(nextEntries, "SUPPORT", field.key, field.locale),
        ]),
      ),
    });
    tradingForm.setFieldsValue({
      ...Object.fromEntries(
        tradingFields.map((field) => [
          field.key,
          entryValue(nextEntries, "TRADING", field.key, locale),
        ]),
      ),
      ...Object.fromEntries(
        tradingFields
          .filter((field) => "title" in field && field.title)
          .map((field) => [
            `${field.key}__title`,
            entryTitle(nextEntries, "TRADING", field.key, locale),
          ]),
      ),
    });
  }

  function applyInsightsForm(
    nextEntries: ContentEntry[],
    locale: "en" | "hi",
  ) {
    insightsForm.setFieldsValue({
      ...Object.fromEntries(
        insightIntroFields.map((field) => [
          field.key,
          entryValue(nextEntries, "INSIGHTS", field.key, locale),
        ]),
      ),
      ...Object.fromEntries(
        insightArticleKeys.flatMap((key) => [
          [key, entryValue(nextEntries, "INSIGHTS", key, locale)],
          [`${key}__title`, entryTitle(nextEntries, "INSIGHTS", key, locale)],
        ]),
      ),
    });
  }

  useEffect(() => {
    void loadAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!entries.length) return;
    applyOpsForms(entries, opsLocale);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [opsLocale, entries]);

  useEffect(() => {
    if (!entries.length) return;
    applyInsightsForm(entries, insightsLocale);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [insightsLocale, entries]);

  async function saveModule(
    module: ContentEntry["module"],
    values: Record<string, string>,
    fields: ReadonlyArray<{ key: string; locale?: string; title?: boolean }>,
  ) {
    setSaving(true);
    try {
      const payload = fields.flatMap((field) => {
        const locale = field.locale ?? "en";
        const body = values[field.key] ?? "";
        const titleKey = `${field.key}__title`;
        return [
          {
            module,
            key: field.key,
            locale,
            body,
            title: field.title ? values[titleKey] || null : undefined,
            isActive: true,
          },
        ];
      });
      await api.post("/admin/app-content/bulk", { entries: payload });
      message.success("配置已保存，客户端下次刷新后生效");
      await loadAll();
    } catch (requestError: unknown) {
      message.error(apiError(requestError, "保存失败"));
    } finally {
      setSaving(false);
    }
  }


  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>客户端运营配置</Title>
          <Paragraph type="secondary">
            维护 APP 可运营文案与入口文案：首页（含个人中心菜单）、充值页、客服、交易/组合、About、法律文本与 Wealth Insights。
            首页/充值/客服客户端文案/交易说明支持 English 与 Hindi；客服标签与快捷回复仍为中文（后台客服台）。
            公司实体图文请到{" "}
            <Link href="/company-showcase">平台公司信息</Link>{" "}
            维护。客户充值仍通过在线客服完成——本页可改充值说明与预填消息，不配置平台收款/银行账户。修改后客户端下次拉取配置即生效，无需发版。
          </Paragraph>
        </div>

        {error && <Alert type="error" title={error} showIcon />}

        <Card
          extra={
            <Space>
              <Text type="secondary">运营文案语言</Text>
              <Select
                value={opsLocale}
                style={{ width: 140 }}
                options={[
                  { value: "en", label: "English" },
                  { value: "hi", label: "Hindi" },
                ]}
                onChange={(value) => setOpsLocale(value)}
              />
              <Button icon={<ReloadOutlined />} loading={loading} onClick={loadAll}>
                刷新
              </Button>
            </Space>
          }
        >
          <Tabs
            items={[
              {
                key: "home",
                label: (
                  <span>
                    <HomeOutlined /> 首页
                  </span>
                ),
                children: (
                  <Form form={homeForm} layout="vertical">
                    <Paragraph type="secondary">
                      当前编辑：{opsLocale === "hi" ? "Hindi" : "English"}。按分组折叠编辑，保存时整页一并提交。
                    </Paragraph>
                    <FieldGroup
                      title="横幅"
                      hint="首页与行情页顶部营销文案"
                      fields={homeBannerFields}
                    />
                    <FieldGroup
                      title="公司展示"
                      hint="公司卡片标题与按钮文案；图文素材在「平台公司信息」维护"
                      fields={homeCompanyFields}
                    />
                    <FieldGroup
                      title="资金入口"
                      hint="Add Funds / Withdraw 与资产卡标签"
                      fields={homeFundsFields}
                    />
                    <FieldGroup
                      title="行情与新闻"
                      hint="指数区、查看全部与新闻空态"
                      fields={homeNewsFields}
                    />
                    <FieldGroup
                      title="个人中心"
                      hint="Profile 分区标题、概览指标与运营入口文案"
                      fields={homeProfileFields}
                    />
                    <FieldGroup
                      title="提现弹窗"
                      hint="首页 Withdraw 打开的提现申请弹窗文案"
                      fields={homeWithdrawFields}
                    />
                    <Button
                      type="primary"
                      icon={<SaveOutlined />}
                      loading={saving}
                      onClick={() =>
                        homeForm.validateFields().then((values) =>
                          saveModule(
                            "HOME",
                            values,
                            homeFields.map((field) => ({
                              key: field.key,
                              locale: opsLocale,
                            })),
                          ),
                        )
                      }
                    >
                      保存首页配置（{opsLocale.toUpperCase()}）
                    </Button>
                  </Form>
                ),
              },
              {
                key: "deposit",
                label: (
                  <span>
                    <DollarOutlined /> 充值页
                  </span>
                ),
                children: (
                  <Form form={depositForm} layout="vertical">
                    <Paragraph type="secondary">
                      维护 Deposit 页展示文案与打开客服时的预填消息（当前{" "}
                      {opsLocale === "hi" ? "Hindi" : "English"}
                      ）。不配置收款账户；入金方式由客服线下提供，财务后台手动上分。
                    </Paragraph>
                    <FieldGroup
                      title="充值页文案"
                      fields={depositFields}
                    />
                    <Button
                      type="primary"
                      icon={<SaveOutlined />}
                      loading={saving}
                      onClick={() =>
                        depositForm.validateFields().then((values) =>
                          saveModule(
                            "DEPOSIT",
                            values,
                            depositFields.map((field) => ({
                              key: field.key,
                              locale: opsLocale,
                            })),
                          ),
                        )
                      }
                    >
                      保存充值页配置（{opsLocale.toUpperCase()}）
                    </Button>
                  </Form>
                ),
              },
              {
                key: "support",
                label: (
                  <span>
                    <CustomerServiceOutlined /> 客服
                  </span>
                ),
                children: (
                  <Form form={supportForm} layout="vertical">
                    <Paragraph type="secondary">
                      侧边悬浮按钮/面板标题/欢迎语/服务时间滚动公告/快捷主题/预填消息/SaleSmartly URL 按运营文案语言编辑（当前{" "}
                      {opsLocale === "hi" ? "Hindi" : "English"}）；标签与快捷回复固定为中文，供后台客服台使用。
                    </Paragraph>
                    <FieldGroup title="客户端客服文案" fields={supportFields} />
                    <Divider />
                    <Text strong>客服台（中文）</Text>
                    <Paragraph type="secondary">
                      仅后台客服工作台使用，不直接展示给 APP 用户。
                    </Paragraph>
                    <Form.Item
                      name={supportTagField.key}
                      label={supportTagField.label}
                      rules={[{ required: true, message: "请填写标签" }]}
                    >
                      <TextArea rows={supportTagField.rows} />
                    </Form.Item>
                    {supportQuickReplies.map((field) => (
                      <Form.Item
                        key={field.key}
                        name={field.key}
                        label={field.label}
                        rules={[{ required: true, message: "请填写快捷回复" }]}
                      >
                        <TextArea rows={3} />
                      </Form.Item>
                    ))}
                    <Button
                      type="primary"
                      icon={<SaveOutlined />}
                      loading={saving}
                      onClick={() =>
                        supportForm.validateFields().then((values) =>
                          saveModule("SUPPORT", values, [
                            ...supportFields.map((field) => ({
                              key: field.key,
                              locale: opsLocale,
                            })),
                            supportTagField,
                            ...supportQuickReplies,
                          ]),
                        )
                      }
                    >
                      保存客服配置（客户端 {opsLocale.toUpperCase()} + 中文快捷回复）
                    </Button>
                  </Form>
                ),
              },
              {
                key: "trading",
                label: (
                  <span>
                    <StockOutlined /> 交易说明
                  </span>
                ),
                children: (
                  <Form form={tradingForm} layout="vertical">
                    <Paragraph type="secondary">
                      当前编辑：{opsLocale === "hi" ? "Hindi" : "English"}
                    </Paragraph>
                    <FieldGroup
                      title="交易中心 Tab / 快捷入口"
                      hint="Trade 页顶部筛选与快捷入口标签"
                      fields={tradingTabFields}
                    />
                    <FieldGroup
                      title="空状态与组合页"
                      hint="涨停股/OTC/IPO 空态、组合页标题与持仓空态"
                      fields={tradingEmptyFields}
                    />
                    <FieldGroup
                      title="交易引导"
                      hint="可同时编辑标题与正文"
                      fields={tradingGuideFields}
                    />
                    <Button
                      type="primary"
                      icon={<SaveOutlined />}
                      loading={saving}
                      onClick={() =>
                        tradingForm.validateFields().then((values) =>
                          saveModule(
                            "TRADING",
                            values,
                            tradingFields.map((field) => ({
                              key: field.key,
                              locale: opsLocale,
                              title: field.title,
                            })),
                          ),
                        )
                      }
                    >
                      保存交易说明（{opsLocale.toUpperCase()}）
                    </Button>
                  </Form>
                ),
              },
              {
                key: "about",
                label: (
                  <span>
                    <InfoCircleOutlined /> About
                  </span>
                ),
                children: (
                  <Form form={aboutForm} layout="vertical">
                    <Paragraph type="secondary">
                      上线前请补齐法律主体、注册地址与申诉联系方式；客户端 About 页会直接展示这些字段。
                    </Paragraph>
                    {aboutFields.map((field) => (
                      <Form.Item key={field.key} name={field.key} label={field.label}>
                        <TextArea rows={field.rows} />
                      </Form.Item>
                    ))}
                    <Button
                      type="primary"
                      icon={<SaveOutlined />}
                      loading={saving}
                      onClick={() =>
                        aboutForm
                          .validateFields()
                          .then((values) =>
                            saveModule("ABOUT", values, [...aboutFields]),
                          )
                      }
                    >
                      保存 About
                    </Button>
                  </Form>
                ),
              },
              {
                key: "legal",
                label: (
                  <span>
                    <FileProtectOutlined /> 法律文本
                  </span>
                ),
                children: (
                  <Form form={legalForm} layout="vertical">
                    <Paragraph type="secondary">
                      正文请使用 JSON：{`{"effective":"...","sections":[{"heading":"...","body":"..."}]}`}
                    </Paragraph>
                    <Form.Item name="privacy.document__title" label="隐私政策标题">
                      <Input />
                    </Form.Item>
                    <Form.Item
                      name="privacy.document"
                      label="隐私政策 JSON"
                      rules={[{ required: true, message: "请填写隐私政策" }]}
                    >
                      <TextArea rows={12} />
                    </Form.Item>
                    <Form.Item name="terms.document__title" label="服务条款标题">
                      <Input />
                    </Form.Item>
                    <Form.Item
                      name="terms.document"
                      label="服务条款 JSON"
                      rules={[{ required: true, message: "请填写服务条款" }]}
                    >
                      <TextArea rows={12} />
                    </Form.Item>
                    <Button
                      type="primary"
                      icon={<SaveOutlined />}
                      loading={saving}
                      onClick={() =>
                        legalForm.validateFields().then((values) =>
                          saveModule("LEGAL", values, [
                            { key: "privacy.document", title: true },
                            { key: "terms.document", title: true },
                          ]),
                        )
                      }
                    >
                      保存法律文本
                    </Button>
                  </Form>
                ),
              },
              {
                key: "insights",
                label: (
                  <span>
                    <BookOutlined /> Wealth Insights
                  </span>
                ),
                children: (
                  <Form form={insightsForm} layout="vertical">
                    <Space style={{ marginBottom: 16 }}>
                      <Text>编辑语言</Text>
                      <Select
                        value={insightsLocale}
                        style={{ width: 160 }}
                        options={[
                          { value: "en", label: "English" },
                          { value: "hi", label: "Hindi" },
                        ]}
                        onChange={(value) => setInsightsLocale(value)}
                      />
                    </Space>
                    {insightIntroFields.map((field) => (
                      <Form.Item key={field.key} name={field.key} label={field.label}>
                        <TextArea rows={field.rows} />
                      </Form.Item>
                    ))}
                    {insightArticleKeys.map((key, index) => (
                      <div key={key}>
                        <Form.Item
                          name={`${key}__title`}
                          label={`文章 ${index + 1} 标题`}
                          rules={[{ required: true, message: "请填写标题" }]}
                        >
                          <Input />
                        </Form.Item>
                        <Form.Item
                          name={key}
                          label={`文章 ${index + 1} 正文`}
                          rules={[{ required: true, message: "请填写正文" }]}
                        >
                          <TextArea rows={5} />
                        </Form.Item>
                      </div>
                    ))}
                    <Button
                      type="primary"
                      icon={<SaveOutlined />}
                      loading={saving}
                      onClick={() =>
                        insightsForm.validateFields().then((values) =>
                          saveModule(
                            "INSIGHTS",
                            values,
                            [
                              ...insightIntroFields.map((field) => ({
                                key: field.key,
                                locale: insightsLocale,
                              })),
                              ...insightArticleKeys.map((key) => ({
                                key,
                                locale: insightsLocale,
                                title: true,
                              })),
                            ],
                          ),
                        )
                      }
                    >
                      保存 Insights（{insightsLocale.toUpperCase()}）
                    </Button>
                  </Form>
                ),
              },
            ]}
          />
        </Card>
      </Space>

    </AdminShell>
  );
}
