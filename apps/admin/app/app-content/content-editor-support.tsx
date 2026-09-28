"use client";

import { Collapse, Form, Input, Space, Tag, Typography } from "antd";

import { missingLocaleKeys } from "./coverage";
import { type FieldDef } from "./fields";

const { Paragraph, Text } = Typography;
const { TextArea } = Input;
export function FieldGroup({
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
                    rules={[
                      { required: true, message: "请填写内容" },
                      ...(field.jsonObject
                        ? [
                            {
                              validator: async (_: unknown, value: string) => {
                                try {
                                  const parsed = JSON.parse(value);
                                  if (
                                    !parsed ||
                                    Array.isArray(parsed) ||
                                    typeof parsed !== "object" ||
                                    Object.entries(parsed).some(
                                      ([key, replacement]) =>
                                        !key.trim() || typeof replacement !== "string",
                                    )
                                  ) {
                                    throw new Error("invalid dictionary");
                                  }
                                } catch {
                                  throw new Error("请输入字符串键值组成的有效 JSON 对象");
                                }
                              },
                            },
                          ]
                        : []),
                    ]}
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

export type ContentEntry = {
  id: string;
  module: "HOME" | "DEPOSIT" | "SUPPORT" | "TRADING" | "LEGAL" | "ABOUT" | "INSIGHTS";
  key: string;
  title?: string | null;
  body: string;
  locale: string;
  isActive: boolean;
  sortOrder: number;
  updatedAt?: string;
  publicationStatus: "DRAFT" | "SCHEDULED" | "PUBLISHED" | "EXPIRED";
  publishAt?: string | null;
  expiresAt?: string | null;
  version: number;
};

export type ContentRevision = {
  id: string;
  action: string;
  createdAt: string;
  actor?: { fullName?: string | null } | null;
  metadata?: { before?: { body?: string }; after?: { body?: string; title?: string | null } | null } | null;
};

export const legalFieldLabels = {
  "privacy.document": "隐私政策",
  "terms.document": "服务条款",
  "risk.document": "风险披露",
} as const;

export function parseLegalDocument(body: string) {
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

export const legalDocumentRule = {
  validator: async (_: unknown, value: string) => {
    parseLegalDocument(value || "");
  },
};


export function apiError(error: unknown, fallback: string) {
  const value = (error as { response?: { data?: { message?: unknown } } })
    ?.response?.data?.message;
  if (Array.isArray(value)) return value.map(String).join("，");
  return value == null ? fallback : String(value);
}

export function entryValue(
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

export function entryTitle(
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

export function SavedLocaleStatus({
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
