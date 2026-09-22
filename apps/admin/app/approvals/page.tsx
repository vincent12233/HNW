"use client";

import { CheckOutlined, CloseOutlined, ReloadOutlined } from "@ant-design/icons";
import { Alert, Button, Input, Space, Table, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import { api, formatCreditSuccessMessage, getApiErrorMessage } from "@/lib/api";
import { maskBankAccount } from "@/lib/ops-directory";
import { formatOpsDateTime } from "@/lib/ops-format";
import { GOVERNANCE_COPY, UNAVAILABLE } from "@/lib/ops-governance";

const { Text } = Typography;

function approvalTypeCode(action?: string | null) {
  const value = action?.toUpperCase() ?? "";
  if (value.includes("CREDIT")) return "CREDIT";
  if (value.includes("DEBIT")) return "DEBIT";
  return "";
}

function approvalTypeLabel(action?: string | null) {
  const code = approvalTypeCode(action);
  if (code === "CREDIT") return "账户入金";
  if (code === "DEBIT") return "账户扣款";
  return action?.trim() || UNAVAILABLE;
}

function displayField(value?: string | null) {
  return value?.trim() ? value : UNAVAILABLE;
}

type Approval = {
  id: string;
  action: string;
  reason: string;
  status: string;
  payload: { accountNumber?: string; amount?: string; referenceId?: string };
  requestedAt: string;
  requestedBy: { fullName: string; role: string };
};

export default function ApprovalsPage() {
  const [rows, setRows] = useState<Approval[]>([]);
  const [loading, setLoading] = useState(false);
  const [note, setNote] = useState("");
  const [selected, setSelected] = useState<Approval | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const submittingRef = useRef(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<Approval[]>("/admin/approvals", { params: { status: "PENDING" } });
      setRows(Array.isArray(data) ? data : []);
    } catch {
      setError("复核任务加载失败，请刷新后重试。");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const decide = async (decision: "APPROVED" | "REJECTED") => {
    if (!selected || submittingRef.current) return;
    submittingRef.current = true;
    setSubmitting(true);
    try {
      const { data } = await api.post(`/admin/approvals/${selected.id}/decision`, {
        decision,
        note,
      });
      if (decision === "APPROVED" && selected.action.includes("CREDIT")) {
        message.success(formatCreditSuccessMessage(data, "已批准并执行入账"));
      } else {
        message.success(decision === "APPROVED" ? "已批准并执行" : "已拒绝");
      }
      setSelected(null);
      setNote("");
      await load();
    } catch (e: unknown) {
      message.error(getApiErrorMessage(e, "操作失败"));
    } finally {
      submittingRef.current = false;
      setSubmitting(false);
    }
  };

  const creditCount = useMemo(() => rows.filter((row) => row.action.includes("CREDIT")).length, [rows]);
  const debitCount = useMemo(() => rows.length - creditCount, [rows, creditCount]);

  const columns: ColumnsType<Approval> = [
    {
      title: "类型",
      dataIndex: "action",
      width: 140,
      render: (value: string) => (
        <OpsStatusTag code={approvalTypeCode(value)} label={approvalTypeLabel(value)} />
      ),
    },
    {
      title: "状态",
      dataIndex: "status",
      width: 120,
      render: (value: string) => <OpsStatusTag code={value} label={displayField(value)} />,
    },
    { title: "账户", width: 160, render: (_, row) => maskBankAccount(row.payload.accountNumber) },
    {
      title: "金额",
      width: 140,
      align: "right",
      render: (_, row) => <OpsMoney value={row.payload.amount} />,
    },
    { title: "业务流水号", width: 180, render: (_, row) => row.payload.referenceId || "—" },
    {
      title: "发起人",
      width: 160,
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text>{row.requestedBy.fullName}</Text>
          <Text type="secondary" style={{ fontSize: 12 }}>
            {row.requestedBy.role}
          </Text>
        </Space>
      ),
    },
    {
      title: "发起时间",
      dataIndex: "requestedAt",
      width: 180,
      render: (value: string) => formatOpsDateTime(value),
    },
    {
      title: "操作",
      fixed: "right",
      width: 120,
      render: (_, row) => (
        <Button
          type="primary"
          aria-label={`复核 ${row.id}`}
          onClick={() => {
            setNote("");
            setSelected(row);
          }}
        >
          独立复核
        </Button>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          eyebrow="ADMIN CONTROL"
          title="余额调整复核（超管）"
          description={`仅用于超级管理员发起的余额调整申请。财务日常上下分/上分订单为单人确认，不走本页。申请人与批准人必须是不同员工。${GOVERNANCE_COPY.noReplay}`}
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()} aria-label="刷新复核任务">
              刷新
            </Button>
          }
        />

        <div className="ops-stat-strip">
          <div className="ops-stat-pill">
            <span className="label">待复核</span>
            <span className="value">{rows.length}</span>
          </div>
          <div className="ops-stat-pill">
            <span className="label">入金类</span>
            <span className="value">{creditCount}</span>
          </div>
          <div className="ops-stat-pill">
            <span className="label">扣款类</span>
            <span className="value">{debitCount}</span>
          </div>
        </div>

        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}

        <Alert
          type="info"
          showIcon
          title="与财务单人上分的区别"
          description="财务后台创建上分订单或直接上下分后立即入账，无需在此复核。本页只处理超管角色队列中的余额调整申请；请勿批准自己发起的申请。"
        />

        <Alert
          type="warning"
          showIcon
          title="独立复核要求"
          description="请勿批准自己发起的申请。若金额、账户或流水号与原始凭证不一致，应直接拒绝。"
        />

        <Table
          rowKey="id"
          className="ops-directory-table"
          loading={loading}
          dataSource={rows}
          columns={columns}
          scroll={{ x: 1100 }}
          pagination={{ pageSize: 20, showTotal: (total) => `共 ${total} 条待复核` }}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载复核任务" : "当前没有待复核申请。"} onRetry={loading ? undefined : () => void load()} /> }}
        />
      </Space>

      <OpsModal
        title="独立复核确认"
        open={!!selected}
        onCancel={() => !submitting && setSelected(null)}
        footer={
          <Space>
            <Button danger icon={<CloseOutlined />} loading={submitting} disabled={submitting} onClick={() => void decide("REJECTED")}>
              拒绝
            </Button>
            <Button type="primary" icon={<CheckOutlined />} loading={submitting} disabled={submitting} onClick={() => void decide("APPROVED")}>
              批准并执行
            </Button>
          </Space>
        }
      >
        {selected && (
          <Space orientation="vertical" size={8} style={{ width: "100%" }}>
            <Text>类型：{approvalTypeLabel(selected.action)}</Text>
            <Text>状态：{displayField(selected.status)}</Text>
            <Text>账户：{maskBankAccount(selected.payload.accountNumber)}</Text>
            <Text>金额：<OpsMoney value={selected.payload.amount} /></Text>
            <Text>流水号：{displayField(selected.payload.referenceId)}</Text>
            <Text type="secondary">
              发起人：{selected.requestedBy.fullName}（{selected.requestedBy.role}）
            </Text>
            {selected.reason ? <Text type="secondary" className="ops-wrap-text">申请原因：{selected.reason}</Text> : null}
            <Input.TextArea
              rows={3}
              value={note}
              disabled={submitting}
              onChange={(event) => setNote(event.target.value)}
              placeholder="复核备注（建议填写）"
              maxLength={300}
            />
          </Space>
        )}
      </OpsModal>
    </AdminShell>
  );
}
