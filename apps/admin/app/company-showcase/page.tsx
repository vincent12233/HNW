"use client";

import { DeleteOutlined, EditOutlined, PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import { Button, Form, Input, InputNumber, Space, Switch, Table, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import { api, getApiErrorMessage } from "@/lib/api";
import { GOVERNANCE_COPY } from "@/lib/ops-governance";

const { Text } = Typography;

type Company = {
  id: string;
  name: string;
  tagline: string;
  description: string;
  logoUrl?: string;
  videoUrl?: string;
  websiteUrl?: string;
  sector?: string;
  status: string;
  sortOrder: number;
};

type CompanyFormValues = {
  name: string;
  tagline: string;
  description: string;
  logoUrl?: string;
  videoUrl?: string;
  websiteUrl?: string;
  sector?: string;
  status?: boolean;
  sortOrder?: number;
};

export default function CompanyShowcasePage() {
  const [rows, setRows] = useState<Company[]>([]);
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Company | null>(null);
  const [pendingDelete, setPendingDelete] = useState<Company | null>(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [form] = Form.useForm<CompanyFormValues>();
  const savingRef = useRef(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<Company[]>("/company-showcase/admin");
      setRows(Array.isArray(data) ? data : []);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "加载公司展示失败"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function save(values: CompanyFormValues) {
    if (savingRef.current) return;
    const payload = {
      ...values,
      status: values.status ? "ACTIVE" : "INACTIVE",
    };
    savingRef.current = true;
    setSaving(true);
    try {
      if (editing) await api.patch(`/company-showcase/${editing.id}`, payload);
      else await api.post("/company-showcase", payload);
      message.success("已保存");
      setOpen(false);
      await load();
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "保存失败"));
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
      await api.delete(`/company-showcase/${row.id}`);
      message.success("已删除");
      setPendingDelete(null);
      await load();
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "删除失败"));
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  }

  const columns: ColumnsType<Company> = [
    {
      title: "公司",
      render: (_, row) => (
        <Space>
          <OpsStatusTag code={row.status} />
          <Space orientation="vertical" size={0}>
            <Text strong className="ops-wrap-text">{row.name}</Text>
            <Text type="secondary" className="ops-wrap-text">{row.tagline}</Text>
          </Space>
        </Space>
      ),
    },
    { title: "行业", dataIndex: "sector", render: (value?: string) => value || "—" },
    { title: "排序", dataIndex: "sortOrder", width: 80 },
    {
      title: "操作",
      width: 180,
      render: (_, row) => (
        <Space>
          <Button
            icon={<EditOutlined />}
            aria-label={`编辑 ${row.name}`}
            onClick={() => {
              setEditing(row);
              form.setFieldsValue({ ...row, status: row.status === "ACTIVE" });
              setOpen(true);
            }}
          >
            编辑
          </Button>
          <Button danger icon={<DeleteOutlined />} aria-label={`删除 ${row.name}`} onClick={() => setPendingDelete(row)} />
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          eyebrow="APP MANAGEMENT"
          title="公司信息"
          description={`维护客户端首页唯一展示的平台公司资料。${GOVERNANCE_COPY.noVip} 外链仅保存为 URL 文本。`}
          extra={
            <Space>
              <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()} aria-label="刷新公司信息">
                刷新
              </Button>
              <Button
                type="primary"
                icon={<PlusOutlined />}
                onClick={() => {
                  setEditing(null);
                  form.resetFields();
                  form.setFieldValue("status", true);
                  setOpen(true);
                }}
              >
                保存公司信息
              </Button>
            </Space>
          }
        />
        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}
        <Table
          rowKey="id"
          className="ops-directory-table"
          loading={loading}
          dataSource={rows.slice(0, 1)}
          columns={columns}
          pagination={false}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载公司信息" : "尚未配置平台公司信息。"} onRetry={loading ? undefined : () => void load()} /> }}
        />
      </Space>
      <OpsModal
        title={editing ? "编辑平台公司信息" : "平台公司信息"}
        open={open}
        onCancel={() => (saving ? undefined : setOpen(false))}
        onOk={() => form.submit()}
        okText="保存"
        confirmLoading={saving}
        okButtonProps={{ disabled: saving }}
      >
        <Form form={form} layout="vertical" onFinish={(values) => void save(values)}>
          <Form.Item name="name" label="公司名称" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <Form.Item name="tagline" label="一句话介绍" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <Form.Item name="description" label="公司简介" rules={[{ required: true }]}>
            <Input.TextArea rows={4} />
          </Form.Item>
          <Space style={{ width: "100%" }}>
            <Form.Item name="sector" label="行业">
              <Input />
            </Form.Item>
            <Form.Item name="sortOrder" label="排序">
              <InputNumber min={0} />
            </Form.Item>
          </Space>
          <Form.Item name="logoUrl" label="Logo URL">
            <Input placeholder="可选 HTTPS 图片地址" />
          </Form.Item>
          <Form.Item name="videoUrl" label="官网展示视频 URL" extra="支持 MP4/HLS 或对象存储中的 HTTPS 视频地址">
            <Input placeholder="https://.../company-video.mp4" />
          </Form.Item>
          <Form.Item name="websiteUrl" label="官网 URL">
            <Input placeholder="可选 HTTPS 链接" />
          </Form.Item>
          <Form.Item name="status" label="首页展示" valuePropName="checked">
            <Switch />
          </Form.Item>
        </Form>
      </OpsModal>
      <OpsModal
        title="删除平台公司信息？"
        open={!!pendingDelete}
        onCancel={() => (saving ? undefined : setPendingDelete(null))}
        onOk={() => void confirmDelete()}
        okText="删除"
        okButtonProps={{ danger: true, disabled: saving }}
        confirmLoading={saving}
      >
        <Text>删除后首页将不再展示平台公司信息。服务器成功后才会从列表移除。</Text>
      </OpsModal>
    </AdminShell>
  );
}
