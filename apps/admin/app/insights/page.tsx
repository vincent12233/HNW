"use client";

import { DeleteOutlined, EditOutlined, PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
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
import { useEffect, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from "@/lib/api";

const { Title, Text, Paragraph } = Typography;
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

  function remove(row: InsightArticle) {
    Modal.confirm({
      title: "删除洞察文章？",
      content: `${row.slug} / ${row.locale}`,
      okButtonProps: { danger: true },
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
      title: "文章",
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
      title: "操作",
      width: 160,
      render: (_, row) => (
        <Space>
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
          <Button danger icon={<DeleteOutlined />} onClick={() => remove(row)} />
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <Space style={{ justifyContent: "space-between", width: "100%" }}>
          <div>
            <Title level={3} style={{ margin: 0 }}>
              洞察文章
            </Title>
            <Paragraph type="secondary" style={{ marginBottom: 0 }}>
              结构化 InsightArticle（Phase 11B 最小管理入口）。旧 KV article.01–08 仍保留兼容。
            </Paragraph>
          </div>
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
              新建
            </Button>
          </Space>
        </Space>

        {error ? (
          <Alert type="error" showIcon title={error} action={<Button onClick={() => void load()}>重试</Button>} />
        ) : null}

        <Card>
          <Table rowKey="id" loading={loading} columns={columns} dataSource={rows} pagination={{ pageSize: 20 }} />
        </Card>
      </Space>

      <Modal
        title={editing ? "编辑洞察文章" : "新建洞察文章"}
        open={open}
        onCancel={() => setOpen(false)}
        onOk={() => form.submit()}
        okText="保存"
        width={720}
        destroyOnHidden
      >
        <Form form={form} layout="vertical" onFinish={(v) => void save(v)}>
          <Space style={{ width: "100%" }} wrap>
            <Form.Item name="slug" label="Slug" rules={[{ required: true }]} style={{ minWidth: 220 }}>
              <Input placeholder="account-and-kyc" disabled={Boolean(editing)} />
            </Form.Item>
            <Form.Item name="locale" label="Locale" rules={[{ required: true }]} style={{ minWidth: 120 }}>
              <Select options={[{ value: "en" }, { value: "hi" }]} />
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
            <TextArea rows={10} />
          </Form.Item>
          <Form.Item name="imageUrl" label="封面图 URL">
            <Input placeholder="可选 HTTPS 图片" />
          </Form.Item>
          <Form.Item name="isPublished" label="发布" valuePropName="checked">
            <Switch />
          </Form.Item>
        </Form>
      </Modal>
    </AdminShell>
  );
}
