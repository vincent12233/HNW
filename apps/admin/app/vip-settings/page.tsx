"use client";

import { Button, Card, Input, InputNumber, Space, Switch, Table, Typography, message } from "antd";
import { ReloadOutlined, SaveOutlined } from "@ant-design/icons";
import { useCallback, useEffect, useRef, useState } from "react";
import AdminShell from "@/components/AdminShell";
import OpsModal from "@/components/OpsModal";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api, getApiErrorMessage } from "@/lib/api";
import { vipTierLabel } from "@/lib/vip";

const { Text } = Typography;

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
  const loadingRef = useRef(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [saveError, setSaveError] = useState("");

  const load = useCallback(async () => {
    if (loadingRef.current) return;
    loadingRef.current = true;
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<TierRow[]>("/admin/vip-tiers");
      setRows(data);
    } catch (err) {
      setError(getApiErrorMessage(err, "VIP 等级配置加载失败，请重试。"));
    } finally {
      loadingRef.current = false;
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

  function save() {
    if (savingRef.current || loadingRef.current || rows.length === 0) return;
    const validationError = validateLocal(rows);
    if (validationError) {
      setSaveError(validationError);
      return;
    }
    setSaveError("");
    setConfirmOpen(true);
  }

  async function confirmSave() {
    if (savingRef.current || loadingRef.current) return;
    savingRef.current = true;
    setSaving(true);
    setSaveError("");
    let completed = 0;
    try {
      for (const row of rows) {
        await api.patch(`/admin/vip-tiers/${row.tierCode}`, {
          displayName: row.displayName,
          description: row.description,
          minimumCumulativeDeposit: parseAmount(row.minimumCumulativeDeposit),
          displayOrder: row.displayOrder,
          isActive: row.isActive,
        });
        completed += 1;
      }
      message.success("VIP 等级设置已保存");
      setConfirmOpen(false);
      await load();
    } catch (err) {
      setSaveError(`${getApiErrorMessage(err, "保存失败，请检查后重试。")} 已确认保存 ${completed}/${rows.length} 条配置，其余结果可能未确认；输入已保留，可重试保存。`);
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  }

  function refresh() {
    if (savingRef.current || confirmOpen) return;
    void load();
  }

  return (
    <AdminShell>
      <Space orientation="vertical" size={16} style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title="VIP 等级设置"
          crumbs={[{ title: "治理与人员" }, { title: "VIP 等级设置" }]}
          description="仅超级管理员可配置累计充值门槛。门槛留空表示该等级未配置；全部留空时系统不会生成建议等级。VIP 只作为普通等级字段，不影响交易、资金、产品、费用、KYC 或风控。"
          extra={
            <Button icon={<ReloadOutlined />} onClick={refresh} disabled={saving || confirmOpen} loading={loading} aria-label="刷新 VIP 等级设置">
              刷新
            </Button>
          }
        />
        {error ? (
          <OpsErrorState title={error} onRetry={saving || confirmOpen || loading ? undefined : refresh} />
        ) : null}
        {saveError && !confirmOpen ? <OpsErrorState title={saveError} /> : null}
        <Card>
          <Space wrap style={{ marginBottom: 12 }}>
            <Button type="primary" icon={<SaveOutlined />} onClick={save} disabled={loading || confirmOpen || rows.length === 0} loading={saving} aria-label="保存 VIP 等级设置">保存设置</Button>
            <Button href="/audit-logs">查看配置审计</Button>
          </Space>
          <Table
            rowKey="tierCode"
            loading={loading}
            pagination={false}
            dataSource={rows}
            locale={{ emptyText: <OpsEmpty description={loading ? "正在加载 VIP 等级" : "暂无 VIP 等级配置"} onRetry={loading ? undefined : () => void load()} /> }}
            scroll={{ x: 960 }}
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
                    disabled={saving || loading || confirmOpen}
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
                    disabled={saving || loading || confirmOpen}
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
                    disabled={saving || loading || confirmOpen}
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
                    disabled={saving || loading || confirmOpen}
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
                    disabled={saving || loading || confirmOpen}
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
      <OpsModal
        title="确认保存 VIP 等级设置？"
        open={confirmOpen}
        onOk={() => void confirmSave()}
        onCancel={() => { if (!savingRef.current) setConfirmOpen(false); }}
        confirmLoading={saving}
        cancelButtonProps={{ disabled: saving }}
        closable={!saving}
        keyboard={!saving}
        okText="确认保存"
        cancelText="取消"
      >
        <Text>保存后只更新建议等级计算，不会自动修改任何客户的当前等级，也不会改变交易或资金规则。</Text>
        {saveError ? <OpsErrorState title={saveError} /> : null}
      </OpsModal>
    </AdminShell>
  );
}
