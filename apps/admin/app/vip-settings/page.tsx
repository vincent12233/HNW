"use client";

import { Alert, Button, Card, Input, InputNumber, Modal, Space, Switch, Table, Typography } from "antd";
import { ReloadOutlined, SaveOutlined } from "@ant-design/icons";
import { useCallback, useEffect, useRef, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from "@/lib/api";
import { vipTierLabel } from "@/lib/vip";

const { Title, Paragraph, Text } = Typography;

type TierRow = {
  tierCode: string;
  displayName: string;
  description: string;
  minimumCumulativeDeposit: string | null;
  displayOrder: number;
  isActive: boolean;
  updatedAt?: string;
  updatedBy?: { fullName?: string | null } | null;
};

function parseAmount(value: string | null) {
  if (value == null || value === "") return null;
  return value;
}

function moneyKey(value: string): string | null {
  if (!/^(0|[1-9]\d*)(\.\d{1,2})?$/.test(value)) return null;
  const [whole, fraction = ""] = value.split(".");
  return `${whole}.${(fraction + "00").slice(0, 2)}`;
}

export default function VipSettingsPage() {
  const [rows, setRows] = useState<TierRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const savingRef = useRef(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<TierRow[]>("/admin/vip-tiers");
      setRows(data);
    } catch (err) {
      setError(getApiErrorMessage(err, "VIP 等级配置加载失败，请重试。"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  function validateLocal(next: TierRow[]) {
    const active = next
      .filter((row) => row.isActive && row.minimumCumulativeDeposit != null && row.minimumCumulativeDeposit !== "")
      .sort((a, b) => a.displayOrder - b.displayOrder);
    const amounts: string[] = [];
    for (const row of active) {
      const key = moneyKey(String(row.minimumCumulativeDeposit));
      if (key == null) return "门槛必须是大于等于 0 的金额，最多两位小数；留空表示未配置。";
      const [whole, fraction] = key.split(".");
      amounts.push(`${whole.padStart(18, "0")}.${fraction}`);
    }
    for (let i = 1; i < amounts.length; i += 1) {
      if (amounts[i] <= amounts[i - 1]) {
        return "已启用等级的非空门槛必须严格递增，且同一金额不能对应多个有效等级。";
      }
    }
    return "";
  }

  async function save() {
    if (savingRef.current) return;
    const message = validateLocal(rows);
    if (message) {
      setError(message);
      return;
    }
    Modal.confirm({
      title: "确认保存 VIP 等级设置？",
      content: "保存后只更新建议等级计算，不会自动修改任何客户的当前等级，也不会改变交易或资金规则。",
      okText: "确认保存",
      cancelText: "取消",
      onOk: async () => {
        savingRef.current = true;
        setSaving(true);
        setError("");
        try {
          for (const row of rows) {
            await api.patch(`/admin/vip-tiers/${row.tierCode}`, {
              displayName: row.displayName,
              description: row.description,
              minimumCumulativeDeposit: parseAmount(row.minimumCumulativeDeposit),
              displayOrder: row.displayOrder,
              isActive: row.isActive,
            });
          }
          await load();
        } catch (err) {
          setError(getApiErrorMessage(err, "保存失败，请检查门槛后重试。"));
        } finally {
          savingRef.current = false;
          setSaving(false);
        }
      },
    });
  }

  return (
    <AdminShell>
      <Space direction="vertical" size={16} style={{ width: "100%" }}>
        <div>
          <Title level={3} style={{ marginBottom: 4 }}>VIP 等级设置</Title>
          <Paragraph type="secondary" style={{ marginBottom: 0 }}>
            仅超级管理员可配置累计充值门槛。门槛留空表示该等级未配置；全部留空时系统不会生成建议等级。VIP 等级不影响交易、资金、产品、费用、KYC 或风控。
          </Paragraph>
        </div>
        {error ? (
          <Alert type="error" showIcon message={error} action={<Button onClick={() => void load()}>重试</Button>} />
        ) : null}
        <Card>
          <Space style={{ marginBottom: 12 }}>
            <Button icon={<ReloadOutlined />} onClick={() => void load()} loading={loading}>刷新</Button>
            <Button type="primary" icon={<SaveOutlined />} onClick={() => void save()} loading={saving}>保存设置</Button>
            <Button href="/audit-logs">查看配置审计</Button>
          </Space>
          <Table
            rowKey="tierCode"
            loading={loading}
            pagination={false}
            dataSource={rows}
            locale={{ emptyText: "暂无 VIP 等级配置" }}
            columns={[
              {
                title: "等级",
                dataIndex: "tierCode",
                render: (value: string) => vipTierLabel(value),
              },
              {
                title: "显示名称",
                dataIndex: "displayName",
                render: (_, row) => (
                  <Input
                    value={row.displayName}
                    disabled={saving}
                    onChange={(event) =>
                      setRows((current) =>
                        current.map((item) =>
                          item.tierCode === row.tierCode
                            ? { ...item, displayName: event.target.value }
                            : item,
                        ),
                      )
                    }
                  />
                ),
              },
              {
                title: "说明",
                dataIndex: "description",
                render: (_, row) => (
                  <Input
                    value={row.description}
                    disabled={saving}
                    onChange={(event) =>
                      setRows((current) =>
                        current.map((item) =>
                          item.tierCode === row.tierCode
                            ? { ...item, description: event.target.value }
                            : item,
                        ),
                      )
                    }
                  />
                ),
              },
              {
                title: "最低累计充值",
                dataIndex: "minimumCumulativeDeposit",
                render: (_, row) => (
                  <Input
                    placeholder="未配置"
                    value={row.minimumCumulativeDeposit ?? ""}
                    disabled={saving}
                    onChange={(event) =>
                      setRows((current) =>
                        current.map((item) =>
                          item.tierCode === row.tierCode
                            ? {
                                ...item,
                                minimumCumulativeDeposit: event.target.value.trim() === "" ? null : event.target.value,
                              }
                            : item,
                        ),
                      )
                    }
                  />
                ),
              },
              {
                title: "排序",
                dataIndex: "displayOrder",
                width: 90,
                render: (_, row) => (
                  <InputNumber
                    min={1}
                    max={40}
                    value={row.displayOrder}
                    disabled={saving}
                    onChange={(value) =>
                      setRows((current) =>
                        current.map((item) =>
                          item.tierCode === row.tierCode
                            ? { ...item, displayOrder: Number(value ?? item.displayOrder) }
                            : item,
                        ),
                      )
                    }
                  />
                ),
              },
              {
                title: "启用",
                dataIndex: "isActive",
                render: (_, row) => (
                  <Switch
                    checked={row.isActive}
                    disabled={saving}
                    onChange={(checked) =>
                      setRows((current) =>
                        current.map((item) =>
                          item.tierCode === row.tierCode ? { ...item, isActive: checked } : item,
                        ),
                      )
                    }
                  />
                ),
              },
            ]}
          />
          <Text type="secondary">未配置时不会产生建议等级。请勿用 0 表示未配置；0 会被视为真实门槛。</Text>
        </Card>
      </Space>
    </AdminShell>
  );
}
