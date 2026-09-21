"use client";

import { ReloadOutlined, SaveOutlined } from "@ant-design/icons";
import {
  Alert,
  Button,
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
import { useEffect, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import { api, getApiErrorMessage } from "@/lib/api";
import { formatOpsDateTime } from "@/lib/ops-format";
import { GOVERNANCE_COPY } from "@/lib/ops-governance";

const { Text } = Typography;
const { TextArea } = Input;

type Platform = "ANDROID" | "IOS" | "WEB";

type AppClientSetting = {
  id: string;
  platform: Platform;
  minVersion: string;
  latestVersion: string;
  forceUpdate: boolean;
  maintenanceMode: boolean;
  maintenanceMessage?: string | null;
  supportUrl?: string | null;
  updateUrl?: string | null;
  updatedAt: string;
};

type FormValues = {
  platform: Platform;
  minVersion: string;
  latestVersion: string;
  forceUpdate?: boolean;
  maintenanceMode?: boolean;
  maintenanceMessage?: string;
  supportUrl?: string;
  updateUrl?: string;
};

/** Matches API UpsertAppClientSettingDto VERSION pattern. */
const VERSION_PATTERN = /^\d{1,4}(\.\d{1,4}){0,3}$/;

const PLATFORMS: Platform[] = ["ANDROID", "IOS", "WEB"];

export default function AppSettingsAdminPage() {
  const [rows, setRows] = useState<AppClientSetting[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [pendingSave, setPendingSave] = useState<FormValues | null>(null);
  const [form] = Form.useForm<FormValues>();
  const savingRef = useRef(false);

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
          updateUrl: preferred.updateUrl ?? undefined,
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function selectPlatform(platform: Platform) {
    const row = rows.find((r) => r.platform === platform);
    form.setFieldsValue({
      platform,
      minVersion: row?.minVersion ?? "0.0.0",
      latestVersion: row?.latestVersion ?? "0.0.0",
      forceUpdate: row?.forceUpdate ?? false,
      maintenanceMode: row?.maintenanceMode ?? false,
      maintenanceMessage: row?.maintenanceMessage ?? undefined,
      supportUrl: row?.supportUrl ?? undefined,
      updateUrl: row?.updateUrl ?? undefined,
    });
  }

  async function persist(values: FormValues) {
    if (savingRef.current) return;
    savingRef.current = true;
    setSaving(true);
    try {
      await api.put(`/admin/app-settings/${values.platform}`, {
        minVersion: values.minVersion.trim(),
        latestVersion: values.latestVersion.trim(),
        forceUpdate: Boolean(values.forceUpdate),
        maintenanceMode: Boolean(values.maintenanceMode),
        maintenanceMessage: values.maintenanceMessage?.trim() || null,
        supportUrl: values.supportUrl?.trim() || null,
        updateUrl: values.updateUrl?.trim() || null,
      });
      message.success("已保存");
      setPendingSave(null);
      await load();
    } catch (e: unknown) {
      message.error(getApiErrorMessage(e, "保存失败"));
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  }

  function confirmAndSave(values: FormValues) {
    const before = rows.find((r) => r.platform === values.platform);
    const turningOnForce =
      Boolean(values.forceUpdate) && !(before?.forceUpdate ?? false);
    const turningOnMaintenance =
      Boolean(values.maintenanceMode) && !(before?.maintenanceMode ?? false);

    if (turningOnForce || turningOnMaintenance) {
      setPendingSave(values);
      return;
    }

    void persist(values);
  }

  const columns: ColumnsType<AppClientSetting> = [
    { title: "平台", dataIndex: "platform", width: 110 },
    { title: "最低版本", dataIndex: "minVersion", width: 120 },
    { title: "最新版本", dataIndex: "latestVersion", width: 120 },
    {
      title: "强制更新",
      dataIndex: "forceUpdate",
      width: 120,
      render: (v: boolean) => <OpsStatusTag code={v ? "LIVE" : "DRAFT"} label={v ? "是" : "否"} />,
    },
    {
      title: "维护模式",
      dataIndex: "maintenanceMode",
      width: 120,
      render: (v: boolean) => <OpsStatusTag code={v ? "EXPIRED" : "LIVE"} label={v ? "开" : "关"} />,
    },
    {
      title: "更新链接",
      dataIndex: "updateUrl",
      ellipsis: true,
      render: (v?: string | null) => v?.trim() || "—",
    },
    {
      title: "更新时间",
      dataIndex: "updatedAt",
      render: (v: string) => formatOpsDateTime(v),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          eyebrow="APP MANAGEMENT"
          title="客户端设置"
          description={`按 ANDROID / IOS / WEB 分别配置版本门禁、维护开关与 updateUrl（商店/下载链接）。不含接口地址、行情源或密钥。${GOVERNANCE_COPY.noVip}`}
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()}>
              刷新
            </Button>
          }
        />

        <Alert
          type="warning"
          showIcon
          title="危险配置"
          description="Force Update 与 Maintenance Mode 开启前会二次确认。开启 Force Update 前请配置有效 http(s) updateUrl，否则客户端会提供 Continue 以避免死锁。每次只保存所选平台。"
        />

        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}

        <Text strong>当前配置</Text>
        <Table
          rowKey="id"
          className="ops-directory-table"
          loading={loading}
          columns={columns}
          dataSource={rows}
          pagination={false}
          scroll={{ x: 960 }}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载客户端设置" : "尚未配置任何平台"} onRetry={loading ? undefined : () => void load()} /> }}
        />

        <Text strong>编辑平台设置</Text>
          <Form
            form={form}
            layout="vertical"
            onFinish={(v) => confirmAndSave(v)}
            style={{ maxWidth: 560 }}
          >
            <Form.Item name="platform" label="平台" rules={[{ required: true }]}>
              <Select
                options={PLATFORMS.map((p) => ({ value: p, label: p }))}
                onChange={(v) => selectPlatform(v)}
              />
            </Form.Item>
            <Form.Item
              name="minVersion"
              label="最低版本 (minVersion)"
              extra="格式示例 1.2.3（与 API DTO 一致：最多四段数字）"
              rules={[
                { required: true },
                {
                  pattern: VERSION_PATTERN,
                  message: "版本格式无效，例如 1.2.3",
                },
              ]}
            >
              <Input placeholder="1.0.0" />
            </Form.Item>
            <Form.Item
              name="latestVersion"
              label="最新版本 (latestVersion)"
              extra="用于提示新版本，非 marketing About 文案"
              rules={[
                { required: true },
                {
                  pattern: VERSION_PATTERN,
                  message: "版本格式无效，例如 1.2.3",
                },
              ]}
            >
              <Input placeholder="1.0.5" />
            </Form.Item>
            <Form.Item
              name="forceUpdate"
              label="强制更新 (Force Update)"
              valuePropName="checked"
              extra="低于 minVersion 时是否必须更新"
            >
              <Switch />
            </Form.Item>
            <Form.Item
              name="maintenanceMode"
              label="维护模式 (Maintenance Mode)"
              valuePropName="checked"
            >
              <Switch />
            </Form.Item>
            <Form.Item name="maintenanceMessage" label="维护说明">
              <TextArea rows={3} />
            </Form.Item>
            <Form.Item
              name="updateUrl"
              label="更新链接 (updateUrl)"
              extra="Play Store / App Store / 下载页。必须 http 或 https。客户端 Update 按钮仅打开此链接，不会使用支持链接。"
              rules={[
                {
                  validator: async (_, value) => {
                    const v = typeof value === "string" ? value.trim() : "";
                    if (!v) return;
                    try {
                      const u = new URL(v);
                      if (u.protocol !== "http:" && u.protocol !== "https:") {
                        throw new Error("protocol");
                      }
                    } catch {
                      throw new Error("请输入有效的 http(s) URL");
                    }
                  },
                },
              ]}
            >
              <Input placeholder="https://play.google.com/store/apps/details?id=…" />
            </Form.Item>
            <Form.Item name="supportUrl" label="支持链接">
              <Input placeholder="可选 HTTPS（客服/帮助，不作更新跳转）" />
            </Form.Item>
            <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={saving} disabled={saving}>
              保存所选平台
            </Button>
          </Form>
      </Space>
      <OpsModal
        title="危险配置确认"
        open={!!pendingSave}
        width={560}
        onCancel={() => (saving ? undefined : setPendingSave(null))}
        onOk={() => pendingSave && void persist(pendingSave)}
        okText="确认保存"
        okButtonProps={{ danger: true, disabled: saving }}
        confirmLoading={saving}
      >
        {pendingSave ? (
          <Space orientation="vertical" size="small" style={{ width: "100%" }}>
            <Text>
              平台：<Text strong>{pendingSave.platform}</Text>
            </Text>
            {pendingSave.forceUpdate && !rows.find((row) => row.platform === pendingSave.platform)?.forceUpdate ? (
              <Alert
                type="error"
                showIcon
                title="即将开启 Force Update"
                description={`低于 minVersion（${pendingSave.minVersion}）的客户端可能被强制更新。`}
              />
            ) : null}
            {pendingSave.maintenanceMode && !rows.find((row) => row.platform === pendingSave.platform)?.maintenanceMode ? (
              <Alert
                type="warning"
                showIcon
                title="即将开启 Maintenance Mode"
                description="仅影响所选平台，不会一键打开全部平台。"
              />
            ) : null}
            <Text type="secondary">
              旧值：forceUpdate={String(rows.find((row) => row.platform === pendingSave.platform)?.forceUpdate ?? false)} /
              maintenance={String(rows.find((row) => row.platform === pendingSave.platform)?.maintenanceMode ?? false)}
            </Text>
            <Text type="secondary">
              新值：forceUpdate={String(Boolean(pendingSave.forceUpdate))} /
              maintenance={String(Boolean(pendingSave.maintenanceMode))}
            </Text>
          </Space>
        ) : null}
      </OpsModal>
    </AdminShell>
  );
}
