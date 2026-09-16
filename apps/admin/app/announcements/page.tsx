"use client";

import { DeleteOutlined, EditOutlined, PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  DatePicker,
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
import dayjs, { type Dayjs } from "dayjs";
import { useEffect, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from "@/lib/api";

const { Title, Text, Paragraph } = Typography;
const { TextArea } = Input;

type Announcement = {
  id: string;
  locale: string;
  title: string;
  body: string;
  type: string;
  isPublished: boolean;
  priority: number;
  startsAt?: string | null;
  endsAt?: string | null;
  sortOrder: number;
};

type FormValues = {
  locale: string;
  title: string;
  body: string;
  type?: string;
  isPublished?: boolean;
  priority?: number;
  sortOrder?: number;
  range?: [Dayjs, Dayjs] | null;
};

const TYPE_OPTIONS = [
  { value: "GENERAL", label: "GENERAL" },
  { value: "MAINTENANCE", label: "MAINTENANCE" },
  { value: "IMPORTANT", label: "IMPORTANT" },
  { value: "MARKET_NOTICE", label: "MARKET_NOTICE" },
];

export default function AnnouncementsAdminPage() {
  const [rows, setRows] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Announcement | null>(null);
  const [form] = Form.useForm<FormValues>();

  async function load() {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<Announcement[]>("/admin/announcements");
      setRows(Array.isArray(data) ? data : []);
    } catch (e: unknown) {
      setError(getApiErrorMessage(e, "公告加载失败"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  async function save(values: FormValues) {
    const startsAt = values.range?.[0]?.toISOString() ?? null;
    const endsAt = values.range?.[1]?.toISOString() ?? null;
    const payload = {
      locale: values.locale,
      title: values.title.trim(),
      body: values.body,
      type: values.type ?? "GENERAL",
      isPublished: Boolean(values.isPublished),
      priority: Number(values.priority ?? 0),
      sortOrder: Number(values.sortOrder ?? 0),
      startsAt,
      endsAt,
    };
    try {
      if (editing) {
        await api.put(`/admin/announcements/${editing.id}`, payload);
      } else {
        await api.post("/admin/announcements", payload);
      }
      message.success("已保存");
      setOpen(false);
      setEditing(null);
      await load();
    } catch (e: unknown) {
      message.error(getApiErrorMessage(e, "保存失败"));
    }
  }

  function remove(row: Announcement) {
    Modal.confirm({
      title: "删除公告？",
      content: row.title,
      okButtonProps: { danger: true },
      onOk: async () => {
        try {
          await api.delete(`/admin/announcements/${row.id}`);
          message.success("已删除");
          await load();
        } catch (e: unknown) {
          message.error(getApiErrorMessage(e, "删除失败"));
        }
      },
    });
  }

  const columns: ColumnsType<Announcement> = [
    {
      title: "公告",
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{row.title}</Text>
          <Text type="secondary">
            {row.locale} · {row.type}
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
    { title: "优先级", dataIndex: "priority", width: 90 },
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
                locale: row.locale,
                title: row.title,
                body: row.body,
                type: row.type,
                isPublished: row.isPublished,
                priority: row.priority,
                sortOrder: row.sortOrder,
                range:
                  row.startsAt || row.endsAt
                    ? [
                        row.startsAt ? dayjs(row.startsAt) : dayjs(),
                        row.endsAt ? dayjs(row.endsAt) : dayjs(),
                      ]
                    : null,
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
              平台公告
            </Title>
            <Paragraph type="secondary" style={{ marginBottom: 0 }}>
              结构化 Announcement（≠ Market News / Banner）。Phase 11B 最小管理入口。
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
                form.setFieldsValue({
                  locale: "en",
                  type: "GENERAL",
                  isPublished: false,
                  priority: 0,
                  sortOrder: 0,
                });
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
        title={editing ? "编辑公告" : "新建公告"}
        open={open}
        onCancel={() => setOpen(false)}
        onOk={() => form.submit()}
        okText="保存"
        width={720}
        destroyOnHidden
      >
        <Form form={form} layout="vertical" onFinish={(v) => void save(v)}>
          <Space wrap style={{ width: "100%" }}>
            <Form.Item name="locale" label="Locale" rules={[{ required: true }]} style={{ minWidth: 120 }}>
              <Select options={[{ value: "en" }, { value: "hi" }]} />
            </Form.Item>
            <Form.Item name="type" label="类型" style={{ minWidth: 180 }}>
              <Select options={TYPE_OPTIONS} />
            </Form.Item>
            <Form.Item name="priority" label="优先级" style={{ minWidth: 120 }}>
              <InputNumber min={0} style={{ width: "100%" }} />
            </Form.Item>
            <Form.Item name="sortOrder" label="排序" style={{ minWidth: 120 }}>
              <InputNumber min={0} style={{ width: "100%" }} />
            </Form.Item>
          </Space>
          <Form.Item name="title" label="标题" rules={[{ required: true }]}>
            <Input maxLength={200} />
          </Form.Item>
          <Form.Item name="body" label="正文" rules={[{ required: true }]}>
            <TextArea rows={8} />
          </Form.Item>
          <Form.Item name="range" label="生效区间">
            <DatePicker.RangePicker showTime style={{ width: "100%" }} />
          </Form.Item>
          <Form.Item name="isPublished" label="发布" valuePropName="checked">
            <Switch />
          </Form.Item>
        </Form>
      </Modal>
    </AdminShell>
  );
}
