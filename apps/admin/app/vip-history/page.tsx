"use client";

import { Button, Card, Space, Table } from "antd";
import { ReloadOutlined } from "@ant-design/icons";
import { useCallback, useEffect, useState } from "react";
import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api, getApiErrorMessage } from "@/lib/api";
import { formatOpsDateTime } from "@/lib/ops-format";
import { vipTierLabel, type VipHistoryRow } from "@/lib/vip";

export default function VipHistoryPage() {
  const [rows, setRows] = useState<VipHistoryRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<VipHistoryRow[]>("/admin/vip-history");
      setRows(data);
    } catch (err) {
      setError(getApiErrorMessage(err, "VIP 等级变更历史加载失败，请重试。"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <AdminShell>
      <Space direction="vertical" size={16} style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title="VIP 等级变更历史"
          crumbs={[{ title: "治理与人员" }, { title: "VIP 等级变更历史" }]}
          description="记录人工调整前后的等级、原因、累计充值快照和建议等级。不包含完整手机号、KYC 或银行信息。VIP 没有特殊交易或资金规则。"
          extra={
            <Button icon={<ReloadOutlined />} onClick={() => void load()} loading={loading} aria-label="刷新 VIP 历史">
              刷新
            </Button>
          }
        />
        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}
        <Card className="vip-history-page">
          <Button icon={<ReloadOutlined />} onClick={() => void load()} loading={loading} aria-label="刷新 VIP 历史" style={{ marginBottom: 12 }}>
            刷新
          </Button>
          <Table
            rowKey="id"
            loading={loading}
            dataSource={rows}
            locale={{ emptyText: <OpsEmpty description={loading ? "正在加载 VIP 历史" : "暂无 VIP 等级变更记录"} onRetry={loading ? undefined : () => void load()} /> }}
            scroll={{ x: 960 }}
            columns={[
              { title: "时间", dataIndex: "changedAt", render: (value: string) => formatOpsDateTime(value) },
              { title: "客户", dataIndex: "displayName", render: (value, row) => `${value} · ${row.clientId ?? "-"}` },
              { title: "手机号", dataIndex: "maskedPhone", render: (value) => value || "-" },
              { title: "原等级", dataIndex: "previousTier", render: vipTierLabel },
              { title: "新等级", dataIndex: "newTier", render: vipTierLabel },
              { title: "当时建议", dataIndex: "suggestedTierAtChange", render: vipTierLabel },
              { title: "累计充值快照", dataIndex: "cumulativeDepositAtChange" },
              {
                title: "原因",
                dataIndex: "reason",
                render: (value) => <span className="vip-wrap-text">{value}</span>,
              },
              { title: "操作人", dataIndex: ["changedBy", "fullName"] },
            ]}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
