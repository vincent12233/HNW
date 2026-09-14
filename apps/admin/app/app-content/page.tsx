"use client";

import {
  BankOutlined,
  BookOutlined,
  CustomerServiceOutlined,
  FileProtectOutlined,
  HomeOutlined,
  InfoCircleOutlined,
  PlusOutlined,
  ReloadOutlined,
  SaveOutlined,
  StockOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Form,
  Input,
  InputNumber,
  Modal,
  Popconfirm,
  Select,
  Space,
  Switch,
  Table,
  Tabs,
  Tag,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;
const { TextArea } = Input;

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

type DepositAccount = {
  id: string;
  label: string;
  method: string;
  accountName?: string | null;
  bankName?: string | null;
  accountNumber?: string | null;
  ifsc?: string | null;
  upiId?: string | null;
  notes?: string | null;
  isActive: boolean;
  sortOrder: number;
};

const homeFields = [
  { key: "banner.title", label: "首页横幅标题", rows: 2 },
  { key: "banner.subtitle", label: "首页横幅副标题", rows: 2 },
  { key: "markets.banner.title", label: "行情页横幅标题", rows: 2 },
  { key: "markets.banner.subtitle", label: "行情页横幅副标题", rows: 2 },
] as const;

const depositFields = [
  { key: "instructions", label: "充值说明（客户端展示）", rows: 5 },
  { key: "chat_preset", label: "点击充值时预填客服消息", rows: 3 },
  { key: "api_reject_message", label: "客户端入金接口拒绝提示", rows: 3 },
] as const;

const supportFields = [
  { key: "greeting", label: "客服欢迎语", rows: 3 },
  { key: "hours", label: "服务时间说明", rows: 2 },
  { key: "chat_preset.help", label: "帮助入口预填消息", rows: 2 },
  { key: "salesmartly_script_url", label: "SaleSmartly Script URL", rows: 2 },
] as const;

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

const tradingFields = [
  { key: "institutional.empty_title", label: "机构空状态标题", rows: 2 },
  { key: "institutional.empty_subtitle", label: "机构空状态说明", rows: 3 },
  { key: "otc.empty_title", label: "OTC 空状态标题", rows: 2 },
  { key: "otc.empty_subtitle", label: "OTC 空状态说明", rows: 3 },
  { key: "ipo.confirm_template", label: "IPO 提交确认文案（可用 {current}/{max}）", rows: 4 },
  { key: "guide.institutional", label: "交易说明 · 机构", rows: 4, title: true },
  { key: "guide.otc", label: "交易说明 · OTC", rows: 4, title: true },
  { key: "guide.ipo", label: "交易说明 · IPO", rows: 4, title: true },
] as const;

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
  const [accounts, setAccounts] = useState<DepositAccount[]>([]);
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
  const [insightsLocale, setInsightsLocale] = useState<"en" | "hi">("en");
  const [accountOpen, setAccountOpen] = useState(false);
  const [editingAccount, setEditingAccount] = useState<DepositAccount | null>(
    null,
  );
  const [accountForm] = Form.useForm();

  async function loadAll() {
    setLoading(true);
    setError("");
    try {
      const [contentResponse, accountResponse] = await Promise.all([
        api.get<ContentEntry[]>("/admin/app-content"),
        api.get<DepositAccount[]>("/admin/app-content/deposit-accounts"),
      ]);
      const nextEntries = Array.isArray(contentResponse.data)
        ? contentResponse.data
        : [];
      const nextAccounts = Array.isArray(accountResponse.data)
        ? accountResponse.data
        : [];
      setEntries(nextEntries);
      setAccounts(nextAccounts);
      homeForm.setFieldsValue(
        Object.fromEntries(
          homeFields.map((field) => [
            field.key,
            entryValue(nextEntries, "HOME", field.key),
          ]),
        ),
      );
      depositForm.setFieldsValue(
        Object.fromEntries(
          depositFields.map((field) => [
            field.key,
            entryValue(nextEntries, "DEPOSIT", field.key),
          ]),
        ),
      );
      supportForm.setFieldsValue({
        ...Object.fromEntries(
          supportFields.map((field) => [
            field.key,
            entryValue(nextEntries, "SUPPORT", field.key),
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
            entryValue(nextEntries, "TRADING", field.key),
          ]),
        ),
        ...Object.fromEntries(
          tradingFields
            .filter((field) => "title" in field && field.title)
            .map((field) => [
              `${field.key}__title`,
              entryTitle(nextEntries, "TRADING", field.key),
            ]),
        ),
      });
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
      insightsForm.setFieldsValue({
        ...Object.fromEntries(
          insightIntroFields.map((field) => [
            field.key,
            entryValue(nextEntries, "INSIGHTS", field.key, insightsLocale),
          ]),
        ),
        ...Object.fromEntries(
          insightArticleKeys.flatMap((key) => [
            [key, entryValue(nextEntries, "INSIGHTS", key, insightsLocale)],
            [
              `${key}__title`,
              entryTitle(nextEntries, "INSIGHTS", key, insightsLocale),
            ],
          ]),
        ),
      });
    } catch (requestError: unknown) {
      setError(apiError(requestError, "运营配置加载失败"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!entries.length) return;
    insightsForm.setFieldsValue({
      ...Object.fromEntries(
        insightIntroFields.map((field) => [
          field.key,
          entryValue(entries, "INSIGHTS", field.key, insightsLocale),
        ]),
      ),
      ...Object.fromEntries(
        insightArticleKeys.flatMap((key) => [
          [key, entryValue(entries, "INSIGHTS", key, insightsLocale)],
          [
            `${key}__title`,
            entryTitle(entries, "INSIGHTS", key, insightsLocale),
          ],
        ]),
      ),
    });
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

  function openAccount(record?: DepositAccount) {
    setEditingAccount(record ?? null);
    accountForm.setFieldsValue(
      record ?? {
        method: "BANK",
        isActive: true,
        sortOrder: accounts.length,
      },
    );
    setAccountOpen(true);
  }

  async function submitAccount() {
    const values = await accountForm.validateFields();
    try {
      if (editingAccount) {
        await api.patch(
          `/admin/app-content/deposit-accounts/${editingAccount.id}`,
          values,
        );
        message.success("收款账户已更新");
      } else {
        await api.post("/admin/app-content/deposit-accounts", values);
        message.success("收款账户已添加");
      }
      setAccountOpen(false);
      setEditingAccount(null);
      await loadAll();
    } catch (requestError: unknown) {
      message.error(apiError(requestError, "收款账户保存失败"));
    }
  }

  const accountColumns: ColumnsType<DepositAccount> = useMemo(
    () => [
      { title: "名称", dataIndex: "label", width: 160 },
      {
        title: "方式",
        dataIndex: "method",
        width: 90,
        render: (value) => <Tag>{value}</Tag>,
      },
      {
        title: "账户信息",
        render: (_, record) => (
          <Space orientation="vertical" size={0}>
            <Text>{record.accountName || record.upiId || "-"}</Text>
            <Text type="secondary">
              {record.method === "UPI"
                ? record.upiId
                : [record.bankName, record.accountNumber, record.ifsc]
                    .filter(Boolean)
                    .join(" · ") || "-"}
            </Text>
          </Space>
        ),
      },
      {
        title: "状态",
        dataIndex: "isActive",
        width: 110,
        render: (value: boolean, record) => (
          <Switch
            checked={value}
            checkedChildren="启用"
            unCheckedChildren="停用"
            onChange={async (checked) => {
              await api.patch(
                `/admin/app-content/deposit-accounts/${record.id}/status`,
                { isActive: checked },
              );
              await loadAll();
            }}
          />
        ),
      },
      {
        title: "操作",
        width: 160,
        render: (_, record) => (
          <Space>
            <Button size="small" onClick={() => openAccount(record)}>
              编辑
            </Button>
            <Popconfirm
              title="确认删除该收款账户？"
              okText="删除"
              cancelText="取消"
              onConfirm={async () => {
                await api.delete(
                  `/admin/app-content/deposit-accounts/${record.id}`,
                );
                message.success("已删除");
                await loadAll();
              }}
            >
              <Button size="small" danger>
                删除
              </Button>
            </Popconfirm>
          </Space>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [accounts.length],
  );

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>客户端运营配置</Title>
          <Paragraph type="secondary">
            维护 APP 首页、充值、客服、交易说明、About、法律文本与 Wealth Insights。修改后客户端下次拉取配置即生效，无需发版。
          </Paragraph>
        </div>

        {error && <Alert type="error" title={error} showIcon />}

        <Card
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={loadAll}>
              刷新
            </Button>
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
                    {homeFields.map((field) => (
                      <Form.Item
                        key={field.key}
                        name={field.key}
                        label={field.label}
                        rules={[{ required: true, message: "请填写内容" }]}
                      >
                        <TextArea rows={field.rows} />
                      </Form.Item>
                    ))}
                    <Button
                      type="primary"
                      icon={<SaveOutlined />}
                      loading={saving}
                      onClick={() =>
                        homeForm
                          .validateFields()
                          .then((values) =>
                            saveModule("HOME", values, [...homeFields]),
                          )
                      }
                    >
                      保存首页配置
                    </Button>
                  </Form>
                ),
              },
              {
                key: "deposit",
                label: (
                  <span>
                    <BankOutlined /> 充值
                  </span>
                ),
                children: (
                  <Space orientation="vertical" size="large" style={{ width: "100%" }}>
                    <Form form={depositForm} layout="vertical">
                      {depositFields.map((field) => (
                        <Form.Item
                          key={field.key}
                          name={field.key}
                          label={field.label}
                          rules={[{ required: true, message: "请填写内容" }]}
                        >
                          <TextArea rows={field.rows} />
                        </Form.Item>
                      ))}
                      <Button
                        type="primary"
                        icon={<SaveOutlined />}
                        loading={saving}
                        onClick={() =>
                          depositForm
                            .validateFields()
                            .then((values) =>
                              saveModule("DEPOSIT", values, [...depositFields]),
                            )
                        }
                      >
                        保存充值文案
                      </Button>
                    </Form>

                    <Card
                      size="small"
                      title="平台收款账户"
                      extra={
                        <Button
                          type="primary"
                          icon={<PlusOutlined />}
                          onClick={() => openAccount()}
                        >
                          新增账户
                        </Button>
                      }
                    >
                      <Paragraph type="secondary">
                        这些账户会随充值配置下发给客户端，供客服或充值说明引用；不会自动完成上分。
                      </Paragraph>
                      <Table
                        rowKey="id"
                        columns={accountColumns}
                        dataSource={accounts}
                        loading={loading}
                        pagination={false}
                      />
                    </Card>
                  </Space>
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
                    {supportFields.map((field) => (
                      <Form.Item
                        key={field.key}
                        name={field.key}
                        label={field.label}
                      >
                        <TextArea rows={field.rows} />
                      </Form.Item>
                    ))}
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
                            ...supportFields,
                            supportTagField,
                            ...supportQuickReplies,
                          ]),
                        )
                      }
                    >
                      保存客服配置
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
                    {tradingFields.map((field) => (
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
                    <Button
                      type="primary"
                      icon={<SaveOutlined />}
                      loading={saving}
                      onClick={() =>
                        tradingForm
                          .validateFields()
                          .then((values) =>
                            saveModule("TRADING", values, [...tradingFields]),
                          )
                      }
                    >
                      保存交易说明
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

      <Modal
        title={editingAccount ? "编辑收款账户" : "新增收款账户"}
        open={accountOpen}
        onCancel={() => {
          setAccountOpen(false);
          setEditingAccount(null);
        }}
        onOk={submitAccount}
        okText="保存"
        cancelText="取消"
      >
        <Form form={accountForm} layout="vertical">
          <Form.Item
            name="label"
            label="显示名称"
            rules={[{ required: true, message: "请输入名称" }]}
          >
            <Input placeholder="例如 HDFC 对公账户" />
          </Form.Item>
          <Form.Item
            name="method"
            label="收款方式"
            rules={[{ required: true }]}
          >
            <Select
              options={[
                { value: "BANK", label: "银行转账" },
                { value: "UPI", label: "UPI" },
                { value: "OTHER", label: "其他" },
              ]}
            />
          </Form.Item>
          <Form.Item name="accountName" label="账户名">
            <Input />
          </Form.Item>
          <Form.Item name="bankName" label="银行名称">
            <Input />
          </Form.Item>
          <Form.Item name="accountNumber" label="账号">
            <Input />
          </Form.Item>
          <Form.Item name="ifsc" label="IFSC">
            <Input />
          </Form.Item>
          <Form.Item name="upiId" label="UPI ID">
            <Input />
          </Form.Item>
          <Form.Item name="notes" label="备注">
            <TextArea rows={3} />
          </Form.Item>
          <Form.Item name="sortOrder" label="排序">
            <InputNumber min={0} style={{ width: "100%" }} />
          </Form.Item>
          <Form.Item name="isActive" label="启用" valuePropName="checked">
            <Switch />
          </Form.Item>
        </Form>
      </Modal>
    </AdminShell>
  );
}
