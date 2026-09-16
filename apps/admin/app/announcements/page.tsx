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
  DatePicker,
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
import dayjs, { type Dayjs } from "dayjs";
import { useEffect, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api, getApiErrorMessage } from "@/lib/api";

const { Text, Paragraph } = Typography;
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
  updatedAt: string;
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

type DisplayStatus = "Draft" | "Scheduled" | "Live" | "Expired";

function displayStatus(row: Announcement, now = Date.now()): DisplayStatus {
  if (!row.isPublished) return "Draft";
  const start = row.startsAt ? new Date(row.startsAt).getTime() : null;
  const end = row.endsAt ? new Date(row.endsAt).getTime() : null;
  if (end != null && end < now) return "Expired";
  if (start != null && start > now) return "Scheduled";
  return "Live";
}

function statusColor(status: DisplayStatus) {
  switch (status) {
    case "Live":
      return "green";
    case "Scheduled":
      return "blue";
    case "Expired":
      return "default";
    default:
      return "gold";
  }
}

export default function AnnouncementsAdminPage() {
  const [rows, setRows] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [open, setOpen] = useState(false);
  const [preview, setPreview] = useState<Announcement | null>(null);
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
    if (startsAt && endsAt && new Date(endsAt) < new Date(startsAt)) {
      message.error("结束时间不得早于开始时间");
      return;
    }
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

  async function setPublished(row: Announcement, isPublished: boolean) {
    try {
      await api.put(`/admin/announcements/${row.id}`, {
        locale: row.locale,
        title: row.title,
        body: row.body,
        type: row.type,
        priority: row.priority,
        sortOrder: row.sortOrder,
        startsAt: row.startsAt,
        endsAt: row.endsAt,
        isPublished,
      });
      message.success(isPublished ? "已发布" : "已下架");
      await load();
    } catch (e: unknown) {
      message.error(getApiErrorMessage(e, "状态更新失败"));
    }
  }

  function remove(row: Announcement) {
    Modal.confirm({
      title: "删除公告？",
      content: `确认删除「${row.title}」？`,
      okText: "删除",
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
      title: "标题",
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
      width: 120,
      render: (_, row) => {
        const status = displayStatus(row);
        return <Tag color={statusColor(status)}>{status}</Tag>;
      },
    },
    { title: "优先级", dataIndex: "priority", width: 90 },
    {
      title: "生效区间",
      width: 220,
      render: (_, row) => (
        <Text type="secondary">
          {row.startsAt ? new Date(row.startsAt).toLocaleString("zh-CN") : "—"}
          {" → "}
          {row.endsAt ? new Date(row.endsAt).toLocaleString("zh-CN") : "—"}
        </Text>
      ),
    },
    {
      title: "更新",
      width: 170,
      render: (_, row) => new Date(row.updatedAt).toLocaleString("zh-CN"),
    },
    {
      title: "操作",
      width: 280,
      render: (_, row) => (
        <Space wrap>
          <Button icon={<EyeOutlined />} onClick={() => setPreview(row)}>
            预览
          </Button>
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
          title="平台公告"
          description="结构化 Announcement。≠ Market News，≠ Home/Markets Banner。状态由发布开关与时间窗计算（Draft / Scheduled / Live / Expired）。"
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
                新建公告
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
            pagination={{ pageSize: 20, showTotal: (t) => `共 ${t} 条` }}
            locale={{ emptyText: "暂无公告" }}
          />
        </Card>
      </Space>

      <Modal
        title={editing ? "编辑公告" : "新建公告"}
        open={open}
        onCancel={() => setOpen(false)}
        onOk={() => form.submit()}
        okText="保存"
        width={760}
        destroyOnHidden
      >
        <Form form={form} layout="vertical" onFinish={(v) => void save(v)}>
          <Space wrap style={{ width: "100%" }}>
            <Form.Item name="locale" label="Locale" rules={[{ required: true }]} style={{ minWidth: 120 }}>
              <Select options={[{ value: "en", label: "English" }, { value: "hi", label: "Hindi" }]} />
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
          <Form.Item name="range" label="生效区间（可选）">
            <DatePicker.RangePicker showTime style={{ width: "100%" }} />
          </Form.Item>
          <Form.Item name="isPublished" label="发布" valuePropName="checked">
            <Switch />
          </Form.Item>
        </Form>
      </Modal>

      <Drawer title="公告预览" open={Boolean(preview)} onClose={() => setPreview(null)} width={480}>
        {preview ? (
          <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
            <Space>
              <Tag color={statusColor(displayStatus(preview))}>{displayStatus(preview)}</Tag>
              <Tag>{preview.type}</Tag>
            </Space>
            <Typography.Title level={4} style={{ margin: 0 }}>
              {preview.title}
            </Typography.Title>
            <Paragraph style={{ whiteSpace: "pre-wrap" }}>{preview.body}</Paragraph>
          </Space>
        ) : null}
      </Drawer>
    </AdminShell>
  );
}
