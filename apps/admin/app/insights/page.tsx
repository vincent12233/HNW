"use client";

import {
  DeleteOutlined,
  EditOutlined,
  EyeOutlined,
  PlusOutlined,
  ReloadOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Drawer,
  Form,
  Input,
  InputNumber,
  Modal,
  Select,
  Space,
  Switch,
  Table,
  Tag,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import Link from "next/link";
import { useEffect, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api, getApiErrorMessage } from "@/lib/api";

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
  const [form] = Form.useForm<FormValues>();

  async function load() {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<InsightArticle[]>("/admin/insights");
      setRows(Array.isArray(data) ? data : []);
    } catch (e: unknown) {
      setError(getApiErrorMessage(e, "洞察文章加载失败"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  async function save(values: FormValues) {
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
    }
  }

  async function setPublished(row: InsightArticle, isPublished: boolean) {
    try {
      await api.put(`/admin/insights/${row.id}`, {
        slug: row.slug,
        locale: row.locale,
        title: row.title,
        summary: row.summary,
        body: row.body,
        imageUrl: row.imageUrl,
        sortOrder: row.sortOrder,
        isPublished,
      });
      message.success(isPublished ? "已发布" : "已下架");
      await load();
    } catch (e: unknown) {
      message.error(getApiErrorMessage(e, "状态更新失败"));
    }
  }

  function remove(row: InsightArticle) {
    Modal.confirm({
      title: row.isPublished ? "删除已发布文章？" : "删除文章？",
      content: row.isPublished
        ? `建议先下架。确认删除「${row.title}」(${row.slug}/${row.locale})？此操作不可恢复。`
        : `确认删除「${row.title}」(${row.slug}/${row.locale})？`,
      okText: "删除",
      okButtonProps: { danger: true },
      cancelText: "取消",
      onOk: async () => {
        try {
          await api.delete(`/admin/insights/${row.id}`);
          message.success("已删除");
          await load();
        } catch (e: unknown) {
          message.error(getApiErrorMessage(e, "删除失败"));
        }
      },
    });
  }

  const columns: ColumnsType<InsightArticle> = [
    {
      title: "标题",
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{row.title}</Text>
          <Text type="secondary">
            {row.slug} · {row.locale}
          </Text>
        </Space>
      ),
    },
    {
      title: "状态",
      width: 110,
      render: (_, row) => (
        <Tag color={row.isPublished ? "green" : "default"}>
          {row.isPublished ? "已发布" : "草稿"}
        </Tag>
      ),
    },
    { title: "排序", dataIndex: "sortOrder", width: 80 },
    {
      title: "发布时间",
      width: 170,
      render: (_, row) =>
        row.publishedAt ? new Date(row.publishedAt).toLocaleString("zh-CN") : "—",
    },
    {
      title: "更新时间",
      width: 170,
      render: (_, row) => new Date(row.updatedAt).toLocaleString("zh-CN"),
    },
    {
      title: "操作",
      width: 280,
      render: (_, row) => (
        <Space wrap>
          <Button
            icon={<EyeOutlined />}
            onClick={() => setPreview(row)}
            aria-label={`预览 ${row.title}`}
          >
            预览
          </Button>
          <Button
            icon={<EditOutlined />}
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
          <Button onClick={() => void setPublished(row, !row.isPublished)}>
            {row.isPublished ? "下架" : "发布"}
          </Button>
          <Button danger icon={<DeleteOutlined />} onClick={() => remove(row)}>
            删除
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          eyebrow="APP MANAGEMENT"
          title="洞察文章"
          description={
            <>
              结构化 InsightArticle 管理。新文章请在此维护。旧 KV article.01–08 仅作兼容，见{" "}
              <Link href="/app-content">文案配置 · Legacy Insights</Link>。
            </>
          }
          extra={
            <Space>
              <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()}>
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

        {error ? (
          <Alert
            type="error"
            showIcon
            title={error}
            action={<Button onClick={() => void load()}>重试</Button>}
          />
        ) : null}

        <Card>
          <Table
            rowKey="id"
            loading={loading}
            columns={columns}
            dataSource={rows}
            pagination={{ pageSize: 20, showTotal: (t) => `共 ${t} 篇` }}
            locale={{ emptyText: "暂无文章" }}
          />
        </Card>
      </Space>

      <Modal
        title={editing ? "编辑洞察文章" : "新建洞察文章"}
        open={open}
        onCancel={() => setOpen(false)}
        onOk={() => form.submit()}
        okText="保存"
        width={760}
        destroyOnHidden
      >
        <Form form={form} layout="vertical" onFinish={(v) => void save(v)}>
          <Space wrap style={{ width: "100%" }}>
            <Form.Item name="slug" label="Slug" rules={[{ required: true }]} style={{ minWidth: 220 }}>
              <Input placeholder="account-and-kyc" disabled={Boolean(editing)} />
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
      </Modal>

      <Drawer
        title="内容预览"
        open={Boolean(preview)}
        onClose={() => setPreview(null)}
        width={520}
      >
        {preview ? (
          <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
            <Tag color={preview.isPublished ? "green" : "default"}>
              {preview.isPublished ? "已发布" : "草稿"}
            </Tag>
            <Text type="secondary">
              {preview.slug} · {preview.locale}
            </Text>
            <Typography.Title level={4} style={{ margin: 0 }}>
              {preview.title}
            </Typography.Title>
            {preview.summary ? <Paragraph type="secondary">{preview.summary}</Paragraph> : null}
            <Paragraph style={{ whiteSpace: "pre-wrap" }}>{preview.body}</Paragraph>
          </Space>
        ) : null}
      </Drawer>
    </AdminShell>
  );
}
