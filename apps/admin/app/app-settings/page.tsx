"use client";

import { ReloadOutlined, SaveOutlined } from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Form,
  Input,
  Select,
  Space,
  Switch,
  Table,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from "@/lib/api";

const { Title, Paragraph } = Typography;
const { TextArea } = Input;

type AppClientSetting = {
  id: string;
  platform: "ANDROID" | "IOS" | "WEB";
  minVersion: string;
  latestVersion: string;
  forceUpdate: boolean;
  maintenanceMode: boolean;
  maintenanceMessage?: string | null;
  supportUrl?: string | null;
  updatedAt: string;
};

type FormValues = {
  platform: AppClientSetting["platform"];
  minVersion: string;
  latestVersion: string;
  forceUpdate?: boolean;
  maintenanceMode?: boolean;
  maintenanceMessage?: string;
  supportUrl?: string;
};

const PLATFORMS: AppClientSetting["platform"][] = ["ANDROID", "IOS", "WEB"];

export default function AppSettingsAdminPage() {
  const [rows, setRows] = useState<AppClientSetting[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [form] = Form.useForm<FormValues>();

  async function load() {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<AppClientSetting[]>("/admin/app-settings");
      const list = Array.isArray(data) ? data : [];
      setRows(list);
      const preferred = list.find((r) => r.platform === "ANDROID") ?? list[0];
      if (preferred) {
        form.setFieldsValue({
          platform: preferred.platform,
          minVersion: preferred.minVersion,
          latestVersion: preferred.latestVersion,
          forceUpdate: preferred.forceUpdate,
          maintenanceMode: preferred.maintenanceMode,
          maintenanceMessage: preferred.maintenanceMessage ?? undefined,
          supportUrl: preferred.supportUrl ?? undefined,
        });
      } else {
        form.setFieldsValue({
          platform: "ANDROID",
          minVersion: "0.0.0",
          latestVersion: "0.0.0",
          forceUpdate: false,
          maintenanceMode: false,
        });
      }
    } catch (e: unknown) {
      setError(getApiErrorMessage(e, "客户端设置加载失败"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  function selectPlatform(platform: AppClientSetting["platform"]) {
    const row = rows.find((r) => r.platform === platform);
    form.setFieldsValue({
      platform,
      minVersion: row?.minVersion ?? "0.0.0",
      latestVersion: row?.latestVersion ?? "0.0.0",
      forceUpdate: row?.forceUpdate ?? false,
      maintenanceMode: row?.maintenanceMode ?? false,
      maintenanceMessage: row?.maintenanceMessage ?? undefined,
      supportUrl: row?.supportUrl ?? undefined,
    });
  }

  async function save(values: FormValues) {
    setSaving(true);
    try {
      await api.put(`/admin/app-settings/${values.platform}`, {
        minVersion: values.minVersion.trim(),
        latestVersion: values.latestVersion.trim(),
        forceUpdate: Boolean(values.forceUpdate),
        maintenanceMode: Boolean(values.maintenanceMode),
        maintenanceMessage: values.maintenanceMessage?.trim() || null,
        supportUrl: values.supportUrl?.trim() || null,
      });
      message.success("已保存");
      await load();
    } catch (e: unknown) {
      message.error(getApiErrorMessage(e, "保存失败"));
    } finally {
      setSaving(false);
    }
  }

  const columns: ColumnsType<AppClientSetting> = [
    { title: "平台", dataIndex: "platform", width: 110 },
    { title: "最低版本", dataIndex: "minVersion", width: 120 },
    { title: "最新版本", dataIndex: "latestVersion", width: 120 },
    {
      title: "强制更新",
      dataIndex: "forceUpdate",
      width: 100,
      render: (v: boolean) => (v ? "是" : "否"),
    },
    {
      title: "维护模式",
      dataIndex: "maintenanceMode",
      width: 100,
      render: (v: boolean) => (v ? "开" : "关"),
    },
    {
      title: "更新时间",
      dataIndex: "updatedAt",
      render: (v: string) => new Date(v).toLocaleString("zh-CN"),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <Space style={{ justifyContent: "space-between", width: "100%" }}>
          <div>
            <Title level={3} style={{ margin: 0 }}>
              客户端设置
            </Title>
            <Paragraph type="secondary" style={{ marginBottom: 0 }}>
              AppClientSetting：版本门禁与维护开关。不含 API URL / secrets。本阶段不做强制更新 UI。
            </Paragraph>
          </div>
          <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()}>
            刷新
          </Button>
        </Space>

        {error ? (
          <Alert type="error" showIcon title={error} action={<Button onClick={() => void load()}>重试</Button>} />
        ) : null}

        <Card title="当前配置">
          <Table
            rowKey="id"
            loading={loading}
            columns={columns}
            dataSource={rows}
            pagination={false}
            locale={{ emptyText: "尚未配置任何平台（保存后会出现）" }}
          />
        </Card>

        <Card title="编辑平台设置">
          <Form form={form} layout="vertical" onFinish={(v) => void save(v)} style={{ maxWidth: 560 }}>
            <Form.Item name="platform" label="平台" rules={[{ required: true }]}>
              <Select
                options={PLATFORMS.map((p) => ({ value: p, label: p }))}
                onChange={(v) => selectPlatform(v)}
              />
            </Form.Item>
            <Form.Item
              name="minVersion"
              label="最低版本 (minVersion)"
              extra="低于此版本可能无法继续使用"
              rules={[{ required: true }]}
            >
              <Input placeholder="1.0.0" />
            </Form.Item>
            <Form.Item
              name="latestVersion"
              label="最新版本 (latestVersion)"
              extra="用于提示新版本，非 marketing About 文案"
              rules={[{ required: true }]}
            >
              <Input placeholder="1.0.5" />
            </Form.Item>
            <Form.Item name="forceUpdate" label="强制更新" valuePropName="checked">
              <Switch />
            </Form.Item>
            <Form.Item name="maintenanceMode" label="维护模式" valuePropName="checked">
              <Switch />
            </Form.Item>
            <Form.Item name="maintenanceMessage" label="维护说明">
              <TextArea rows={3} />
            </Form.Item>
            <Form.Item name="supportUrl" label="支持链接">
              <Input placeholder="可选 HTTPS" />
            </Form.Item>
            <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={saving}>
              保存
            </Button>
          </Form>
        </Card>
      </Space>
    </AdminShell>
  );
}
