"use client";

import { Alert, Button, Card, Space, Table, Typography } from "antd";
import { ReloadOutlined } from "@ant-design/icons";
import { useCallback, useEffect, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from "@/lib/api";
import { vipTierLabel, type VipHistoryRow } from "@/lib/vip";

const { Title, Paragraph } = Typography;

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
      <Space direction="vertical" size={16} style={{ width: "100%" }}>
        <div>
          <Title level={3} style={{ marginBottom: 4 }}>VIP 等级变更历史</Title>
          <Paragraph type="secondary" style={{ marginBottom: 0 }}>
            记录人工调整前后的等级、原因、累计充值快照和建议等级。不包含完整手机号、KYC 或银行信息。
          </Paragraph>
        </div>
        {error ? (
          <Alert type="error" showIcon message={error} action={<Button onClick={() => void load()}>重试</Button>} />
        ) : null}
        <Card>
          <Button icon={<ReloadOutlined />} onClick={() => void load()} loading={loading} style={{ marginBottom: 12 }}>
            刷新
          </Button>
          <Table
            rowKey="id"
            loading={loading}
            dataSource={rows}
            locale={{ emptyText: "暂无 VIP 等级变更记录" }}
            scroll={{ x: 960 }}
            columns={[
              { title: "时间", dataIndex: "changedAt" },
              { title: "客户", dataIndex: "displayName", render: (value, row) => `${value} · ${row.clientId ?? "-"}` },
              { title: "手机号", dataIndex: "maskedPhone", render: (value) => value || "-" },
              { title: "原等级", dataIndex: "previousTier", render: vipTierLabel },
              { title: "新等级", dataIndex: "newTier", render: vipTierLabel },
              { title: "当时建议", dataIndex: "suggestedTierAtChange", render: vipTierLabel },
              { title: "累计充值快照", dataIndex: "cumulativeDepositAtChange" },
              { title: "原因", dataIndex: "reason" },
              { title: "操作人", dataIndex: ["changedBy", "fullName"] },
            ]}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
