"use client";

import {
  DeleteOutlined,
  EditOutlined,
  EyeOutlined,
  PlusOutlined,
  ReloadOutlined,
} from "@ant-design/icons";
import { Button, Form, Input, InputNumber, Select, Space, Switch, Table, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsDrawer from "@/components/OpsDrawer";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import { api, getApiErrorMessage } from "@/lib/api";
import { formatOpsDateTime } from "@/lib/ops-format";
import { GOVERNANCE_COPY } from "@/lib/ops-governance";

const { Text, Paragraph } = Typography;
const { TextArea } = Input;

type InsightArticle = {
  id: string;
  slug: string;
  locale: string;
  title: string;
  summary?: string | null;
  body: string;
  imageUrl?: string | null;
  isPublished: boolean;
  sortOrder: number;
  publishedAt?: string | null;
  updatedAt: string;
};

type FormValues = {
  slug: string;
  locale: string;
  title: string;
  summary?: string;
  body: string;
  imageUrl?: string;
  isPublished?: boolean;
  sortOrder?: number;
};

export default function InsightsAdminPage() {
  const [rows, setRows] = useState<InsightArticle[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [open, setOpen] = useState(false);
  const [preview, setPreview] = useState<InsightArticle | null>(null);
  const [editing, setEditing] = useState<InsightArticle | null>(null);
  const [pendingPublish, setPendingPublish] = useState<InsightArticle | null>(null);
  const [pendingDelete, setPendingDelete] = useState<InsightArticle | null>(null);
  const [saving, setSaving] = useState(false);
  const [form] = Form.useForm<FormValues>();
  const savingRef = useRef(false);
  const loadGeneration = useRef(0);

  const load = useCallback(async () => {
    const generation = ++loadGeneration.current;
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<InsightArticle[]>("/admin/insights");
      if (generation !== loadGeneration.current) return;
      setRows(Array.isArray(data) ? data : []);
    } catch (e: unknown) {
      if (generation === loadGeneration.current) {
        setError(getApiErrorMessage(e, "洞察文章加载失败"));
      }
    } finally {
      if (generation === loadGeneration.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function save(values: FormValues) {
    if (savingRef.current) return;
    const payload = {
      slug: values.slug.trim(),
      locale: values.locale,
      title: values.title.trim(),
      summary: values.summary?.trim() || null,
      body: values.body,
      imageUrl: values.imageUrl?.trim() || null,
      isPublished: Boolean(values.isPublished),
      sortOrder: Number(values.sortOrder ?? 0),
    };
    savingRef.current = true;
    setSaving(true);
    try {
      if (editing) {
        await api.put(`/admin/insights/${editing.id}`, payload);
      } else {
        await api.post("/admin/insights", payload);
      }
      message.success("已保存");
      setOpen(false);
      setEditing(null);
      await load();
    } catch (e: unknown) {
      message.error(getApiErrorMessage(e, "保存失败"));
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  }

  async function confirmPublish() {
    const row = pendingPublish;
    if (!row || savingRef.current) return;
    savingRef.current = true;
    setSaving(true);
    try {
      await api.put(`/admin/insights/${row.id}`, {
        slug: row.slug,
        locale: row.locale,
        title: row.title,
        summary: row.summary,
        body: row.body,
        imageUrl: row.imageUrl,
        sortOrder: row.sortOrder,
        isPublished: !row.isPublished,
      });
      message.success(row.isPublished ? "已下架" : "已发布");
      setPendingPublish(null);
      await load();
    } catch (e: unknown) {
      message.error(getApiErrorMessage(e, "状态更新失败"));
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  }

  async function confirmDelete() {
    const row = pendingDelete;
    if (!row || savingRef.current) return;
    savingRef.current = true;
    setSaving(true);
    try {
      await api.delete(`/admin/insights/${row.id}`);
      message.success("已删除");
      setPendingDelete(null);
      await load();
    } catch (e: unknown) {
      message.error(getApiErrorMessage(e, "删除失败"));
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  }

  const columns: ColumnsType<InsightArticle> = [
    {
      title: "标题",
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong className="ops-wrap-text">{row.title}</Text>
          <Text type="secondary">
            {row.slug} · {row.locale}
          </Text>
        </Space>
      ),
    },
    {
      title: "状态",
      width: 120,
      render: (_, row) => <OpsStatusTag code={row.isPublished ? "PUBLISHED" : "DRAFT"} />,
    },
    { title: "排序", dataIndex: "sortOrder", width: 80 },
    {
      title: "发布时间",
      width: 180,
      render: (_, row) => formatOpsDateTime(row.publishedAt),
    },
    {
      title: "更新时间",
      width: 180,
      render: (_, row) => formatOpsDateTime(row.updatedAt),
    },
    {
      title: "操作",
      width: 280,
      render: (_, row) => (
        <Space wrap>
          <Button icon={<EyeOutlined />} onClick={() => setPreview(row)} aria-label={`预览 ${row.title}`}>
            预览
          </Button>
          <Button
            icon={<EditOutlined />}
            aria-label={`编辑 ${row.title}`}
            onClick={() => {
              setEditing(row);
              form.setFieldsValue({
                slug: row.slug,
                locale: row.locale,
                title: row.title,
                summary: row.summary ?? undefined,
                body: row.body,
                imageUrl: row.imageUrl ?? undefined,
                isPublished: row.isPublished,
                sortOrder: row.sortOrder,
              });
              setOpen(true);
            }}
          >
            编辑
          </Button>
          <Button aria-label={row.isPublished ? `下架 ${row.title}` : `发布 ${row.title}`} onClick={() => setPendingPublish(row)}>
            {row.isPublished ? "下架" : "发布"}
          </Button>
          <Button danger icon={<DeleteOutlined />} aria-label={`删除 ${row.title}`} onClick={() => setPendingDelete(row)}>
            删除
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          eyebrow="APP MANAGEMENT"
          title="洞察文章"
          description={
            <>
              结构化 InsightArticle 管理。新文章请在此维护。旧 KV article.01–08 仅作兼容，见{" "}
              <Link href="/app-content">文案配置 · Legacy Insights</Link>
              。{GOVERNANCE_COPY.noVip} 列表只展示服务端返回的标题、状态和时间。
            </>
          }
          extra={
            <Space>
              <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()} aria-label="刷新洞察文章">
                刷新
              </Button>
              <Button
                type="primary"
                icon={<PlusOutlined />}
                onClick={() => {
                  setEditing(null);
                  form.resetFields();
                  form.setFieldsValue({ locale: "en", isPublished: false, sortOrder: 0 });
                  setOpen(true);
                }}
              >
                新建文章
              </Button>
            </Space>
          }
        />

        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}

        <Table
          rowKey="id"
          className="ops-directory-table"
          loading={loading}
          columns={columns}
          dataSource={rows}
          scroll={{ x: 1200 }}
          pagination={{ pageSize: 20, showTotal: (total) => `共 ${total} 篇` }}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载文章" : "当前没有洞察文章。"} onRetry={loading ? undefined : () => void load()} /> }}
        />
      </Space>

      <OpsModal
        title={editing ? "编辑洞察文章" : "新建洞察文章"}
        open={open}
        onCancel={() => (saving ? undefined : setOpen(false))}
        onOk={() => form.submit()}
        okText="保存"
        confirmLoading={saving}
        cancelButtonProps={{ disabled: saving }}
        closable={!saving}
        keyboard={!saving}
        okButtonProps={{ disabled: saving }}
        width={760}
      >
        <Form form={form} layout="vertical" disabled={saving} onFinish={(values) => void save(values)}>
          <Space wrap style={{ width: "100%" }}>
            <Form.Item name="slug" label="Slug" rules={[{ required: true }]} style={{ minWidth: 220 }}>
              <Input placeholder="account-and-kyc" disabled={saving || Boolean(editing)} />
            </Form.Item>
            <Form.Item name="locale" label="Locale" rules={[{ required: true }]} style={{ minWidth: 120 }}>
              <Select options={[{ value: "en", label: "English" }, { value: "hi", label: "Hindi" }]} />
            </Form.Item>
            <Form.Item name="sortOrder" label="排序" style={{ minWidth: 120 }}>
              <InputNumber min={0} style={{ width: "100%" }} />
            </Form.Item>
          </Space>
          <Form.Item name="title" label="标题" rules={[{ required: true }]}>
            <Input maxLength={200} />
          </Form.Item>
          <Form.Item name="summary" label="摘要">
            <TextArea rows={2} maxLength={2000} />
          </Form.Item>
          <Form.Item name="body" label="正文" rules={[{ required: true }]}>
            <TextArea rows={12} />
          </Form.Item>
          <Form.Item name="imageUrl" label="封面图 URL（可选）">
            <Input placeholder="https://..." />
          </Form.Item>
          <Form.Item name="isPublished" label="发布" valuePropName="checked">
            <Switch />
          </Form.Item>
        </Form>
      </OpsModal>

      <OpsModal
        title={pendingPublish?.isPublished ? "确认下架文章？" : "确认发布文章？"}
        open={!!pendingPublish}
        onCancel={() => (saving ? undefined : setPendingPublish(null))}
        onOk={() => void confirmPublish()}
        okText="确认"
        confirmLoading={saving}
        cancelButtonProps={{ disabled: saving }}
        closable={!saving}
        keyboard={!saving}
        okButtonProps={{ disabled: saving }}
      >
        <Text>标题：{pendingPublish?.title}</Text>
      </OpsModal>

      <OpsModal
        title={pendingDelete?.isPublished ? "删除已发布文章？" : "删除文章？"}
        open={!!pendingDelete}
        onCancel={() => (saving ? undefined : setPendingDelete(null))}
        onOk={() => void confirmDelete()}
        okText="删除"
        okButtonProps={{ danger: true, disabled: saving }}
        confirmLoading={saving}
        cancelButtonProps={{ disabled: saving }}
        closable={!saving}
        keyboard={!saving}
      >
        <Text>
          {pendingDelete?.isPublished
            ? `建议先下架。确认删除「${pendingDelete.title}」？服务器成功后才会从列表移除。`
            : `确认删除「${pendingDelete?.title}」？`}
        </Text>
      </OpsModal>

      <OpsDrawer title="内容预览" open={Boolean(preview)} onClose={() => setPreview(null)} width={520}>
        {preview ? (
          <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
            <OpsStatusTag code={preview.isPublished ? "PUBLISHED" : "DRAFT"} />
            <Text type="secondary">
              {preview.slug} · {preview.locale}
            </Text>
            <Text strong>{preview.title}</Text>
            {preview.summary ? <Paragraph type="secondary" className="ops-wrap-text">{preview.summary}</Paragraph> : null}
            <Paragraph className="ops-wrap-text" style={{ whiteSpace: "pre-wrap" }}>{preview.body}</Paragraph>
          </Space>
        ) : null}
      </OpsDrawer>
    </AdminShell>
  );
}
