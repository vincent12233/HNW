"use client";

import { ReloadOutlined } from "@ant-design/icons";
import { Button, Descriptions, Skeleton, Space, Typography } from "antd";
import { useCallback, useEffect, useRef, useState } from "react";
import AdminShell from "@/components/AdminShell";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api } from "@/lib/api";
import { formatOpsDateTime } from "@/lib/ops-format";

type VersionView = { version?: string; commit?: string; builtAt?: string };
const { Text } = Typography;

function safeReleaseValue(value?: string) {
  const cleaned = value?.trim() ?? "";
  return cleaned && cleaned.length <= 80 ? cleaned : "Unavailable";
}

export default function SystemDeploymentsPage() {
  const [view, setView] = useState<VersionView | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const inFlight = useRef(false);
  const load = useCallback(async () => {
    if (inFlight.current) return;
    inFlight.current = true;
    setLoading(true);
    setError("");
    try {
      const response = await api.get<VersionView>("/health/version");
      setView(response.data);
    } catch {
      setError("部署状态暂时不可用。未使用缓存或推测值。");
    } finally {
      inFlight.current = false;
      setLoading(false);
    }
  }, []);
  useEffect(() => void load(), [load]);

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          title="部署状态"
          crumbs={[{ title: "系统治理" }, { title: "部署状态" }]}
          description="只读核对 API 发布身份。部署、回滚和迁移必须通过受保护的 CI 环境执行。"
          extra={<Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()}>刷新</Button>}
        />
        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}
        {loading && !view ? <Skeleton active /> : null}
        {view ? (
          <Descriptions bordered column={1} size="small">
            <Descriptions.Item label="应用版本">{safeReleaseValue(view.version)}</Descriptions.Item>
            <Descriptions.Item label="Git 提交">{safeReleaseValue(view.commit)}</Descriptions.Item>
            <Descriptions.Item label="构建时间">{formatOpsDateTime(view.builtAt)}</Descriptions.Item>
            <Descriptions.Item label="变更控制"><Text>只读 · 无服务器命令 · 无密钥值</Text></Descriptions.Item>
          </Descriptions>
        ) : null}
      </Space>
    </AdminShell>
  );
}
