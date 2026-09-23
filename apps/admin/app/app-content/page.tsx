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
  Modal,
  Select,
  Space,
  Tag,
  Tabs,
  Typography,
  message,
} from "antd";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api } from "@/lib/api";
import { missingLocaleKeys } from "./coverage";
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

const { Paragraph, Text } = Typography;
const { TextArea } = Input;

function FieldGroup({
  title,
  hint,
  fields,
  defaultOpen = false,
}: {
  title: string;
  hint?: string;
  fields: ReadonlyArray<FieldDef>;
  defaultOpen?: boolean;
}) {
  return (
    <Collapse
      defaultActiveKey={defaultOpen ? [title] : []}
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
              <Paragraph type="secondary" style={{ fontSize: 12 }}>
                仅修改展示文案，不改变业务逻辑。
              </Paragraph>
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
  updatedAt?: string;
};

const legalFieldLabels = {
  "privacy.document": "隐私政策",
  "terms.document": "服务条款",
  "risk.document": "风险披露",
} as const;

function parseLegalDocument(body: string) {
  let document: unknown;
  try {
    document = JSON.parse(body);
  } catch {
    throw new Error("请输入有效的 JSON，检查引号、逗号和括号");
  }
  if (typeof document !== "object" || document === null) {
    throw new Error("法律文档必须是包含 effective 和 sections 的 JSON 对象");
  }
  const value = document as {
    effective?: unknown;
    sections?: unknown;
  };
  if (typeof value.effective !== "string" || !value.effective.trim()) {
    throw new Error("请填写 effective 生效日期及版本");
  }
  if (
    !Array.isArray(value.sections) ||
    !value.sections.length ||
    value.sections.some(
      (section: unknown) =>
        typeof section !== "object" ||
        section === null ||
        typeof (section as Record<string, unknown>).heading !== "string" ||
        !(section as { heading: string }).heading.trim() ||
        typeof (section as Record<string, unknown>).body !== "string" ||
        !(section as { body: string }).body.trim(),
    )
  ) {
    throw new Error("sections 至少需要一个段落，每段都要填写 heading 和 body");
  }
  return {
    effective: value.effective,
    sections: value.sections as { heading: string; body: string }[],
  };
}

const legalDocumentRule = {
  validator: async (_: unknown, value: string) => {
    parseLegalDocument(value || "");
  },
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

function SavedLocaleStatus({
  entries,
  module,
  keyName,
}: {
  entries: ContentEntry[];
  module: ContentEntry["module"];
  keyName: string;
}) {
  return (
    <Space size={4} wrap aria-label={`${keyName} 已保存语言状态`}>
      {(["en", "hi"] as const).map((locale) => {
        const missing = missingLocaleKeys(entries, module, [keyName], locale).length > 0;
        return (
          <Tag key={locale} color={missing ? "error" : "success"}>
            {locale.toUpperCase()} {missing ? "缺失" : "已配置"}
          </Tag>
        );
      })}
    </Space>
  );
}

export default function AppOpsContentPage() {
  const [entries, setEntries] = useState<ContentEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const savingRef = useRef(false);
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
  const [aboutLocale, setAboutLocale] = useState<"en" | "hi">("en");
  const [legalLocale, setLegalLocale] = useState<"en" | "hi">("en");
  const [legalPreview, setLegalPreview] = useState<{
    title: string;
    body: string;
  } | null>(null);

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
            entryValue(nextEntries, "ABOUT", field.key, aboutLocale),
          ]),
        ),
      );
      legalForm.setFieldsValue({
        "privacy.document": entryValue(nextEntries, "LEGAL", "privacy.document", legalLocale),
        "terms.document": entryValue(nextEntries, "LEGAL", "terms.document", legalLocale),
        "risk.document": entryValue(nextEntries, "LEGAL", "risk.document", legalLocale),
        "privacy.document__title": entryTitle(
          nextEntries,
          "LEGAL",
          "privacy.document",
          legalLocale,
        ),
        "terms.document__title": entryTitle(
          nextEntries,
          "LEGAL",
          "terms.document",
          legalLocale,
        ),
        "risk.document__title": entryTitle(
          nextEntries,
          "LEGAL",
          "risk.document",
          legalLocale,
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
  }, [opsLocale]);

  useEffect(() => {
    if (!entries.length) return;
    applyInsightsForm(entries, insightsLocale);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [insightsLocale]);

  useEffect(() => {
    if (!entries.length) return;
    aboutForm.setFieldsValue(Object.fromEntries(aboutFields.map((field) => [field.key, entryValue(entries, "ABOUT", field.key, aboutLocale)])));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [aboutLocale]);

  useEffect(() => {
    if (!entries.length) return;
    legalForm.setFieldsValue({
      "privacy.document": entryValue(entries, "LEGAL", "privacy.document", legalLocale),
      "terms.document": entryValue(entries, "LEGAL", "terms.document", legalLocale),
      "risk.document": entryValue(entries, "LEGAL", "risk.document", legalLocale),
      "privacy.document__title": entryTitle(entries, "LEGAL", "privacy.document", legalLocale),
      "terms.document__title": entryTitle(entries, "LEGAL", "terms.document", legalLocale),
      "risk.document__title": entryTitle(entries, "LEGAL", "risk.document", legalLocale),
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [legalLocale]);

  function changeDocumentLanguage(module: "ABOUT" | "LEGAL", next: "en" | "hi") {
    if (savingRef.current || loading) return;
    const form = module === "ABOUT" ? aboutForm : legalForm;
    const currentLocale = module === "ABOUT" ? aboutLocale : legalLocale;
    if (next === currentLocale) return;
    const values = form.getFieldsValue(true) as Record<string, string>;
    const dirty = Object.entries(values).some(([key, value]) => {
      const isTitle = key.endsWith("__title");
      const contentKey = isTitle ? key.slice(0, -7) : key;
      const saved = isTitle ? entryTitle(entries, module, contentKey, currentLocale) : entryValue(entries, module, contentKey, currentLocale);
      return (value ?? "") !== saved;
    });
    const change = () => {
      setLegalPreview(null);
      if (module === "ABOUT") setAboutLocale(next);
      else setLegalLocale(next);
    };
    if (!dirty) { change(); return; }
    Modal.confirm({
      title: "切换语言并放弃未保存修改？",
      content: "当前语言的修改尚未保存。取消后可先保存，再切换语言。",
      okText: "放弃修改并切换",
      cancelText: "继续编辑",
      onOk: change,
    });
  }

  function confirmDiscard(action: () => void, title: string) {
    if (savingRef.current || loading) return;
    Modal.confirm({
      title,
      content: "此操作会重新填充表单。请先保存需要保留的修改。",
      okText: "继续并重新加载",
      cancelText: "继续编辑",
      onOk: action,
    });
  }

  async function saveModule(
    module: ContentEntry["module"],
    values: Record<string, string>,
    fields: ReadonlyArray<{ key: string; locale?: string; title?: boolean }>,
  ) {
    if (savingRef.current) return;
    savingRef.current = true;
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
      const { data: savedEntries } = await api.post<ContentEntry[]>("/admin/app-content/bulk", { entries: payload });
      setEntries((current) => {
        const updated = new Map(current.map((entry) => [`${entry.module}:${entry.locale}:${entry.key}`, entry]));
        for (const entry of savedEntries) {
          updated.set(`${entry.module}:${entry.locale}:${entry.key}`, entry);
        }
        return [...updated.values()];
      });
      message.success("当前模块已保存，其他模块未保存的修改已保留。请在 App 刷新验证。");
    } catch (requestError: unknown) {
      message.error(`${apiError(requestError, "保存失败")} 当前输入已保留；批量保存可能部分成功，请重试当前模块。`);
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  }


  const missingAboutHi = missingLocaleKeys(
    entries,
    "ABOUT",
    aboutFields.map((field) => field.key),
    "hi",
  );
  const missingLegalHi = missingLocaleKeys(
    entries,
    "LEGAL",
    Object.keys(legalFieldLabels),
    "hi",
  );

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          eyebrow="APP MANAGEMENT"
          title="文案配置"
          description={
            <>
              KV App Content：Home / Deposit / Support / Trading / Legal / About。
              结构化内容请使用{" "}
              <Link href="/app-management">APP 管理总览</Link> 中的 Insights /
              Announcements / Settings / Featured。公司图文见{" "}
              <Link href="/company-showcase">平台公司信息</Link>。
            </>
          }
          extra={
            <Space wrap>
              <Text type="secondary">编辑语言</Text>
              <Select
                value={opsLocale}
                style={{ width: 160 }}
                options={[
                  { value: "en", label: "English" },
                  { value: "hi", label: "Hindi" },
                ]}
                disabled={loading || saving}
                onChange={(value) => confirmDiscard(() => setOpsLocale(value), "切换运营文案语言？")}
                aria-label="运营文案语言"
              />
              <Button icon={<ReloadOutlined />} loading={loading} disabled={saving} onClick={() => confirmDiscard(() => void loadAll(), "刷新全部文案？")}>
                刷新
              </Button>
            </Space>
          }
        />

        {error && <Alert type="error" title={error} showIcon />}

        <Card loading={loading}>
          <Alert
            type="info"
            showIcon
            title="本页管理运营文案，不是全部 App 界面编辑器"
            description="仅配置下方已列出的字段；页面布局、品牌样式及部分按钮和表单文案仍需版本更新。Legal 与 About 在各自页签中选择 English / Hindi，缺失语言可能回退到英文或内置文案。保存后请在 App 刷新对应页面；客户端内容缓存有效期为 5 分钟，并非保存后立即推送到所有设备。"
          />
          <Tabs
            items={[
              {
                key: "home",
                label: (
                  <span>
                    <HomeOutlined /> Home
                  </span>
                ),
                children: (
                  <Form form={homeForm} layout="vertical" disabled={saving}>
                    <Alert
                      type="info"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title={`当前语言：${opsLocale === "hi" ? "Hindi" : "English"}`}
                      description="分组默认折叠。仅修改展示文案，不改变业务逻辑。"
                    />
                    <FieldGroup
                      title="Banner"
                      hint="首页与行情页顶部营销文案（title / subtitle / CTA）"
                      fields={homeBannerFields}
                      defaultOpen
                    />
                    <FieldGroup
                      title="Account / Funds labels"
                      hint="Add Funds / Withdraw / Trade 与资产卡标签"
                      fields={homeFundsFields}
                    />
                    <FieldGroup
                      title="Market section"
                      hint="指数区、查看全部"
                      fields={homeNewsFields.filter((f) =>
                        ["indices.section_title", "view_all_cta"].includes(f.key),
                      )}
                    />
                    <FieldGroup
                      title="News section"
                      hint="市场新闻区标题与空态（≠ Announcement）"
                      fields={homeNewsFields.filter((f) => f.key.startsWith("news."))}
                    />
                    <FieldGroup
                      title="Company section"
                      hint="公司卡片标题与按钮文案；素材在「平台公司信息」"
                      fields={homeCompanyFields}
                    />
                    <FieldGroup
                      title="Profile-related labels"
                      hint="Profile 分区标题、概览指标与运营入口文案"
                      fields={homeProfileFields}
                    />
                    <FieldGroup
                      title="Withdrawal dialog copy"
                      hint="首页 Withdraw 弹窗文案"
                      fields={homeWithdrawFields}
                    />
                    <Collapse
                      style={{ marginBottom: 16 }}
                      items={[
                        {
                          key: "legacy",
                          label: <Text type="secondary">Legacy keys</Text>,
                          children: (
                            <FieldGroup
                              title="Legacy HOME"
                              hint="当前 Flutter 未引用；保留数据库行以兼容旧客户端。"
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
                      保存 Home（{opsLocale.toUpperCase()}）
                    </Button>
                  </Form>
                ),
              },
              {
                key: "deposit",
                label: (
                  <span>
                    <DollarOutlined /> Deposit
                  </span>
                ),
                children: (
                  <Form form={depositForm} layout="vertical" disabled={saving}>
                    <Alert
                      type="warning"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title="客户入金仍走现有 Deposit / Support 流程"
                      description="本页只编辑展示文案与客服预填消息。不配置平台银行账户、收款账号或支付通道。KYC Bank Account 仅用于提现/出金，与本页无关。"
                    />
                    <FieldGroup
                      title="Deposit copy"
                      hint={`当前语言：${opsLocale === "hi" ? "Hindi" : "English"}`}
                      fields={depositFields}
                      defaultOpen
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
                      保存 Deposit（{opsLocale.toUpperCase()}）
                    </Button>
                  </Form>
                ),
              },
              {
                key: "support",
                label: (
                  <span>
                    <CustomerServiceOutlined /> Support
                  </span>
                ),
                children: (
                  <Form form={supportForm} layout="vertical" disabled={saving}>
                    <Alert
                      type="info"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title="Client Support Content"
                      description={`问候语、服务时间、主题、预填消息、SaleSmartly Script URL（当前 ${opsLocale === "hi" ? "Hindi" : "English"}）。`}
                    />
                    <FieldGroup
                      title="Client Support Content"
                      fields={supportFields}
                      defaultOpen
                    />
                    <Divider />
                    <Alert
                      type="warning"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title="INTERNAL SUPPORT DESK ONLY"
                      description="标签与中文快捷回复仅供后台客服台，不直接展示给 APP 用户。"
                    />
                    <Form.Item
                      name={supportTagField.key}
                      label={`${supportTagField.label} · INTERNAL`}
                      rules={[{ required: true, message: "请填写标签" }]}
                    >
                      <TextArea rows={supportTagField.rows} />
                    </Form.Item>
                    {supportQuickReplies.map((field) => (
                      <Form.Item
                        key={field.key}
                        name={field.key}
                        label={`${field.label} · INTERNAL`}
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
                      保存 Support（客户端 {opsLocale.toUpperCase()} + 内部桌）
                    </Button>
                  </Form>
                ),
              },
              {
                key: "trading",
                label: (
                  <span>
                    <StockOutlined /> Trading & Portfolio
                  </span>
                ),
                children: (
                  <Form form={tradingForm} layout="vertical" disabled={saving}>
                    <Alert
                      type="warning"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title="Presentation only — 不改变交易规则"
                      description="仅编辑 display / guide / empty-state 文案。不会改变 order rules、matching、price execution、limits、freeze/unfreeze、IPO allocation。"
                    />
                    <FieldGroup
                      title="Tabs & shortcuts"
                      hint="tab.holdings / tab.all 为稳定遗留 key（展示名 Positions / Overview）"
                      fields={tradingTabFields}
                      defaultOpen
                    />
                    <FieldGroup
                      title="Empty states & portfolio"
                      fields={tradingEmptyFields}
                    />
                    <FieldGroup
                      title="Guides (Presentation only)"
                      hint="guide.institutional / otc / ipo 与确认文案仅供说明"
                      fields={tradingGuideFields}
                    />
                    <Collapse
                      style={{ marginBottom: 16 }}
                      items={[
                        {
                          key: "legacy",
                          label: (
                            <Text type="secondary">
                              Legacy keys retained for compatibility
                            </Text>
                          ),
                          children: (
                            <FieldGroup
                              title="Legacy TRADING"
                              hint="当前 Flutter 未引用；保留数据库行。"
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
                      保存 Trading（{opsLocale.toUpperCase()}）
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
                  <Form form={aboutForm} layout="vertical" disabled={saving}>
                    <Space wrap style={{ marginBottom: 16 }}><Text type="secondary">编辑语言</Text><Select value={aboutLocale} style={{ width: 140 }} options={[{ value: "en", label: "English" }, { value: "hi", label: "Hindi" }]} disabled={loading || saving} onChange={(value) => changeDocumentLanguage("ABOUT", value)} aria-label="About 编辑语言" /></Space>
                    <Alert
                      type="info"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title="Company / legal information vs marketing version"
                      description={
                        <>
                          app_version 仅为营销展示文案，≠ 真实构建版本（PackageInfo）。
                          公司展示素材请到{" "}
                          <Link href="/company-showcase">平台公司信息</Link>。
                          ABOUT 与 Legal 可分别编辑 English / Hindi；缺失语言会回退到英文或内置文案。
                        </>
                      }
                    />
                    {missingAboutHi.length > 0 && (
                      <Alert
                        type="warning"
                        showIcon
                        style={{ marginBottom: 16 }}
                        title={`About Hindi 尚缺 ${missingAboutHi.length} 项已保存内容`}
                        description={missingAboutHi
                          .map((key) => aboutFields.find((field) => field.key === key)?.label ?? key)
                          .join("、")}
                      />
                    )}
                    {aboutFields.map((field) => (
                      <Form.Item
                        key={field.key}
                        name={field.key}
                        label={
                          <Space wrap>
                            {field.label}
                            <SavedLocaleStatus entries={entries} module="ABOUT" keyName={field.key} />
                          </Space>
                        }
                      >
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
                            saveModule("ABOUT", values, aboutFields.map((field) => ({ ...field, locale: aboutLocale }))),
                          )
                      }
                    >
                      保存 About（{aboutLocale.toUpperCase()}）
                    </Button>
                  </Form>
                ),
              },
              {
                key: "legal",
                label: (
                  <span>
                    <FileProtectOutlined /> Legal
                  </span>
                ),
                children: (
                  <Form form={legalForm} layout="vertical" disabled={saving}>
                    <Space wrap style={{ marginBottom: 16 }}><Text type="secondary">编辑语言</Text><Select value={legalLocale} style={{ width: 140 }} options={[{ value: "en", label: "English" }, { value: "hi", label: "Hindi" }]} disabled={loading || saving} onChange={(value) => changeDocumentLanguage("LEGAL", value)} aria-label="Legal 编辑语言" /></Space>
                    <Alert
                      type="info"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title="Privacy Policy / Terms of Service / Risk Disclosure"
                      description={
                        <>
                          每份文档分别显示已保存的 English / Hindi 状态。保存前请由运营主体确认最终内容。
                          {" "}
                          Last updated：
                          {(() => {
                            const legalRows = entries.filter(
                              (e) => e.module === "LEGAL" && e.updatedAt,
                            );
                            if (!legalRows.length) return "不可用（条目无 updatedAt）";
                            const latest = legalRows
                              .map((e) => new Date(e.updatedAt!).getTime())
                              .reduce((a, b) => Math.max(a, b), 0);
                            return new Date(latest).toLocaleString("zh-CN");
                          })()}
                        </>
                      }
                    />
                    {missingLegalHi.length > 0 && (
                      <Alert
                        type="warning"
                        showIcon
                        style={{ marginBottom: 16 }}
                        title={`Legal Hindi 尚缺 ${missingLegalHi.length} 份已保存文档`}
                        description={missingLegalHi
                          .map((key) => legalFieldLabels[key as keyof typeof legalFieldLabels])
                          .join("、")}
                      />
                    )}
                    <Paragraph type="secondary">
                      正文 JSON：{`{"effective":"...","sections":[{"heading":"...","body":"..."}]}`}
                    </Paragraph>
                    <Form.Item name="privacy.document__title" label="隐私政策标题">
                      <Input />
                    </Form.Item>
                    <Form.Item
                      name="privacy.document"
                      label={<Space wrap>隐私政策 JSON<SavedLocaleStatus entries={entries} module="LEGAL" keyName="privacy.document" /></Space>}
                      rules={[{ required: true, message: "请填写隐私政策" }, legalDocumentRule]}
                    >
                      <TextArea rows={12} />
                    </Form.Item>
                    <Button
                      style={{ marginBottom: 16 }}
                      onClick={() =>
                        setLegalPreview({
                          title:
                            legalForm.getFieldValue("privacy.document__title") ||
                            "Privacy Policy",
                          body: legalForm.getFieldValue("privacy.document") || "",
                        })
                      }
                    >
                      预览隐私政策
                    </Button>
                    <Form.Item name="terms.document__title" label="服务条款标题">
                      <Input />
                    </Form.Item>
                    <Form.Item
                      name="terms.document"
                      label={<Space wrap>服务条款 JSON<SavedLocaleStatus entries={entries} module="LEGAL" keyName="terms.document" /></Space>}
                      rules={[{ required: true, message: "请填写服务条款" }, legalDocumentRule]}
                    >
                      <TextArea rows={12} />
                    </Form.Item>
                    <Button
                      style={{ marginBottom: 16, marginRight: 8 }}
                      onClick={() =>
                        setLegalPreview({
                          title:
                            legalForm.getFieldValue("terms.document__title") ||
                            "Terms of Service",
                          body: legalForm.getFieldValue("terms.document") || "",
                        })
                      }
                    >
                      预览服务条款
                    </Button>
                    <Form.Item name="risk.document__title" label="风险披露标题">
                      <Input />
                    </Form.Item>
                    <Form.Item
                      name="risk.document"
                      label={<Space wrap>风险披露 JSON<SavedLocaleStatus entries={entries} module="LEGAL" keyName="risk.document" /></Space>}
                      rules={[{ required: true, message: "请填写风险披露" }, legalDocumentRule]}
                    >
                      <TextArea rows={12} />
                    </Form.Item>
                    <Button
                      style={{ marginBottom: 16, marginRight: 8 }}
                      onClick={() =>
                        setLegalPreview({
                          title:
                            legalForm.getFieldValue("risk.document__title") ||
                            "Risk Disclosure",
                          body: legalForm.getFieldValue("risk.document") || "",
                        })
                      }
                    >
                      预览风险披露
                    </Button>
                    <Button
                      type="primary"
                      icon={<SaveOutlined />}
                      loading={saving}
                      onClick={async () => {
                        let values: Record<string, string>;
                        try {
                          values = await legalForm.validateFields();
                        } catch {
                          // Ant Design retains the field validation messages.
                          return;
                        }
                        await saveModule("LEGAL", values, [
                          { key: "privacy.document", title: true, locale: legalLocale },
                          { key: "terms.document", title: true, locale: legalLocale },
                          { key: "risk.document", title: true, locale: legalLocale },
                        ]);
                      }}
                    >
                      保存 Legal（{legalLocale.toUpperCase()}）
                    </Button>
                  </Form>
                ),
              },
              {
                key: "insights-legacy",
                label: (
                  <span>
                    <BookOutlined /> Legacy Insights
                  </span>
                ),
                children: (
                  <Form form={insightsForm} layout="vertical" disabled={saving}>
                    <Alert
                      type="warning"
                      showIcon
                      style={{ marginBottom: 16 }}
                      title="Legacy / Compatibility"
                      description={
                        <>
                          新文章请在{" "}
                          <Link href="/insights">Insights 管理</Link>{" "}
                          中维护。此处 article.01–08 仅保留兼容，不要作为主要编辑入口。
                        </>
                      }
                    />
                    <Space style={{ marginBottom: 16 }}>
                      <Text>兼容编辑语言</Text>
                      <Select
                        value={insightsLocale}
                        style={{ width: 160 }}
                        options={[
                          { value: "en", label: "English" },
                          { value: "hi", label: "Hindi" },
                        ]}
                        disabled={loading || saving}
                        onChange={(value) => confirmDiscard(() => setInsightsLocale(value), "切换兼容文案语言？")}
                      />
                    </Space>
                    <Collapse
                      items={[
                        {
                          key: "intro",
                          label: "Intro（仍可用于列表页介绍文案）",
                          children: insightIntroFields.map((field) => (
                            <Form.Item
                              key={field.key}
                              name={field.key}
                              label={field.label}
                            >
                              <TextArea rows={field.rows} />
                            </Form.Item>
                          )),
                        },
                        {
                          key: "articles",
                          label: "article.01–08（兼容 KV）",
                          children: insightArticleKeys.map((key, index) => (
                            <div key={key}>
                              <Form.Item
                                name={`${key}__title`}
                                label={`文章 ${index + 1} 标题`}
                              >
                                <Input />
                              </Form.Item>
                              <Form.Item name={key} label={`文章 ${index + 1} 正文`}>
                                <TextArea rows={5} />
                              </Form.Item>
                            </div>
                          )),
                        },
                      ]}
                    />
                    <Button
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
                      保存 Legacy Insights（{insightsLocale.toUpperCase()}）
                    </Button>
                  </Form>
                ),
              },
            ]}
          />
        </Card>
      </Space>

      {legalPreview ? (
        <Card
          title={`预览 · ${legalPreview.title}`}
          extra={
            <Button type="link" onClick={() => setLegalPreview(null)}>
              关闭
            </Button>
          }
          style={{
            position: "fixed",
            right: 24,
            bottom: 24,
            width: 420,
            maxWidth: "calc(100vw - 48px)",
            maxHeight: "70vh",
            overflow: "auto",
            zIndex: 1000,
            boxShadow: "0 8px 24px rgba(0,0,0,0.15)",
          }}
        >
          {(() => {
            try {
              const document = parseLegalDocument(legalPreview.body);
              return (
                <>
                  <Paragraph type="secondary">{document.effective}</Paragraph>
                  {document.sections.map((section, index) => (
                    <section key={index}>
                      <Typography.Title level={5}>{section.heading}</Typography.Title>
                      <Paragraph style={{ whiteSpace: "pre-wrap" }}>
                        {section.body}
                      </Paragraph>
                    </section>
                  ))}
                </>
              );
            } catch (previewError) {
              return (
                <Alert
                  type="error"
                  showIcon
                  title="暂时无法预览"
                  description={
                    previewError instanceof Error ? previewError.message : "请检查 JSON 格式"
                  }
                />
              );
            }
          })()}
        </Card>
      ) : null}
    </AdminShell>
  );
}
