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
import {
  aboutFields,
  depositFields,
  homeBannerFields,
  homeCompanyFields,
  homeFields,
  homeFundsFields,
  homeLegacyFields,
  homeNewsFields,
  homeProfileFields,
  homeWithdrawFields,
  insightArticleKeys,
  insightIntroFields,
  supportFields,
  supportQuickReplies,
  supportTagField,
  tradingEmptyFields,
  tradingFields,
  tradingGuideFields,
  tradingLegacyFields,
  tradingTabFields,
  type FieldDef,
} from "./fields";

const { Title, Paragraph, Text } = Typography;
const { TextArea } = Input;

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
        [...homeFields, ...homeLegacyFields].map((field) => [
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
        [...tradingFields, ...tradingLegacyFields].map((field) => [
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
        // Do not send isActive/sortOrder — preserve existing DB values on body edits.
        return [
          {
            module,
            key: field.key,
            locale,
            body,
            title: field.title ? values[titleKey] || null : undefined,
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
                      hint="Add Funds / Withdraw / Trade 与资产卡标签"
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
                    <Collapse
                      style={{ marginBottom: 16 }}
                      items={[
                        {
                          key: "legacy",
                          label: <Text type="secondary">Legacy / 已弃用字段</Text>,
                          children: (
                            <FieldGroup
                              title="Legacy HOME"
                              hint="当前 Flutter 未引用；保留数据库行以兼容旧客户端。不建议继续编辑。"
                              fields={homeLegacyFields}
                            />
                          ),
                        },
                      ]}
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
                            [...homeFields, ...homeLegacyFields].map((field) => ({
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
                      侧边悬浮按钮/面板标题/欢迎语/服务时间滚动公告/快捷主题/预填消息按运营文案语言编辑（当前{" "}
                      {opsLocale === "hi" ? "Hindi" : "English"}）；SaleSmartly Script URL 保存时自动同步 en/hi，供充值页联系客服与侧边悬浮客服共用；标签与快捷回复固定为中文，供后台客服台使用。
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
                    <Alert
                      type="warning"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title="展示文案不影响交易规则"
                      description="交易说明 / IPO 确认文案仅用于客户端展示与教育。下单类型、撮合、冻结、限额、资格与结算以系统交易逻辑为准，CMS 不能改变业务规则。"
                    />
                    <FieldGroup
                      title="交易中心 Tab / 快捷入口"
                      hint="Trade 页顶部筛选与快捷入口。tab.holdings / tab.all 为稳定遗留 key，展示名分别为 Positions / Overview。"
                      fields={tradingTabFields}
                    />
                    <FieldGroup
                      title="空状态与组合页"
                      hint="涨停股/OTC/IPO 空态、组合页标题与 Positions 空态"
                      fields={tradingEmptyFields}
                    />
                    <FieldGroup
                      title="交易引导"
                      hint="可同时编辑标题与正文。内容仅供说明，不改变交易规则。"
                      fields={tradingGuideFields}
                    />
                    <Collapse
                      style={{ marginBottom: 16 }}
                      items={[
                        {
                          key: "legacy",
                          label: <Text type="secondary">Legacy / 已弃用字段</Text>,
                          children: (
                            <FieldGroup
                              title="Legacy TRADING"
                              hint="当前 Flutter 未引用；保留数据库行以兼容旧客户端。"
                              fields={tradingLegacyFields}
                            />
                          ),
                        },
                      ]}
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
                            [...tradingFields, ...tradingLegacyFields].map(
                              (field) => ({
                                key: field.key,
                                locale: opsLocale,
                                title: field.title,
                              }),
                            ),
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
                    <Alert
                      type="info"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title="版本展示文案 ≠ 真实构建版本"
                      description="app_version 仅为营销/展示文案。真实客户端版本以 App 构建元数据为准，请勿将其当作 PackageInfo。"
                    />
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
                    <Alert
                      type="info"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title="法律文本 · Privacy / Terms"
                      description="内容类型为对外法律文档（JSON sections）。保存后客户端下次拉取即生效。请确认文案经合规审核；本页无独立审批流。保存操作已记入 AuditLog。"
                    />
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
