"use client";

import {
  DeleteOutlined,
  EditOutlined,
  EyeOutlined,
  PlusOutlined,
  ReloadOutlined,
} from "@ant-design/icons";
import { Button, DatePicker, Form, Input, InputNumber, Select, Space, Switch, Table, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import dayjs, { type Dayjs } from "dayjs";
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

type DisplayStatus = "DRAFT" | "SCHEDULED" | "LIVE" | "EXPIRED";

function displayStatus(row: Announcement, now = Date.now()): DisplayStatus {
  if (!row.isPublished) return "DRAFT";
  const start = row.startsAt ? new Date(row.startsAt).getTime() : null;
  const end = row.endsAt ? new Date(row.endsAt).getTime() : null;
  if (end != null && end < now) return "EXPIRED";
  if (start != null && start > now) return "SCHEDULED";
  return "LIVE";
}

export default function AnnouncementsAdminPage() {
  const [rows, setRows] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [open, setOpen] = useState(false);
  const [preview, setPreview] = useState<Announcement | null>(null);
  const [editing, setEditing] = useState<Announcement | null>(null);
  const [pendingPublish, setPendingPublish] = useState<Announcement | null>(null);
  const [pendingDelete, setPendingDelete] = useState<Announcement | null>(null);
  const [saving, setSaving] = useState(false);
  const [form] = Form.useForm<FormValues>();
  const savingRef = useRef(false);
  const loadGeneration = useRef(0);

  const load = useCallback(async () => {
    const generation = ++loadGeneration.current;
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<Announcement[]>("/admin/announcements");
      if (generation !== loadGeneration.current) return;
      setRows(Array.isArray(data) ? data : []);
    } catch (e: unknown) {
      if (generation === loadGeneration.current) {
        setError(getApiErrorMessage(e, "公告加载失败"));
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
    savingRef.current = true;
    setSaving(true);
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
      await api.put(`/admin/announcements/${row.id}`, {
        locale: row.locale,
        title: row.title,
        body: row.body,
        type: row.type,
        priority: row.priority,
        sortOrder: row.sortOrder,
        startsAt: row.startsAt,
        endsAt: row.endsAt,
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
      await api.delete(`/admin/announcements/${row.id}`);
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

  const columns: ColumnsType<Announcement> = [
    {
      title: "标题",
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong className="ops-wrap-text">{row.title}</Text>
          <Text type="secondary">
            {row.locale} · {row.type}
          </Text>
        </Space>
      ),
    },
    {
      title: "状态",
      width: 140,
      render: (_, row) => <OpsStatusTag code={displayStatus(row)} />,
    },
    { title: "优先级", dataIndex: "priority", width: 90 },
    {
      title: "生效区间",
      width: 280,
      render: (_, row) => (
        <Text type="secondary">
          {formatOpsDateTime(row.startsAt)} → {formatOpsDateTime(row.endsAt)}
        </Text>
      ),
    },
    {
      title: "更新",
      width: 180,
      render: (_, row) => formatOpsDateTime(row.updatedAt),
    },
    {
      title: "操作",
      width: 280,
      render: (_, row) => (
        <Space wrap>
          <Button icon={<EyeOutlined />} aria-label={`预览 ${row.title}`} onClick={() => setPreview(row)}>
            预览
          </Button>
          <Button
            icon={<EditOutlined />}
            aria-label={`编辑 ${row.title}`}
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
          title="平台公告"
          description={`结构化 Announcement。≠ Market News，≠ Home/Markets Banner。状态由发布开关与时间窗计算（Draft / Scheduled / Live / Expired）。${GOVERNANCE_COPY.noVip} 列表只展示服务端返回的标题、状态和时间。`}
          extra={
            <Space>
              <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()} aria-label="刷新公告列表">
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

        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}

        <Table
          rowKey="id"
          className="ops-directory-table"
          loading={loading}
          columns={columns}
          dataSource={rows}
          scroll={{ x: 1280 }}
          pagination={{ pageSize: 20, showTotal: (total) => `共 ${total} 条` }}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载公告" : "当前没有公告。"} onRetry={loading ? undefined : () => void load()} /> }}
        />
      </Space>

      <OpsModal
        title={editing ? "编辑公告" : "新建公告"}
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
      </OpsModal>

      <OpsModal
        title={pendingPublish?.isPublished ? "确认下架公告？" : "确认发布公告？"}
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
        title="删除公告？"
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
        <Text>确认删除「{pendingDelete?.title}」？服务器成功后才会从列表移除。</Text>
      </OpsModal>

      <OpsDrawer title="公告预览" open={Boolean(preview)} onClose={() => setPreview(null)} width={480}>
        {preview ? (
          <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
            <OpsStatusTag code={displayStatus(preview)} />
            <Text type="secondary">{preview.type}</Text>
            <Text strong>{preview.title}</Text>
            <Paragraph className="ops-wrap-text" style={{ whiteSpace: "pre-wrap" }}>{preview.body}</Paragraph>
          </Space>
        ) : null}
      </OpsDrawer>
    </AdminShell>
  );
}
