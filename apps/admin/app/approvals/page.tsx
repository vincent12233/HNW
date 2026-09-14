"use client";

import { CheckOutlined, CloseOutlined, ReloadOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Modal, Space, Table, Tag, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api } from "@/lib/api";

const { Text } = Typography;

type Approval = {
  id: string;
  action: string;
  reason: string;
  status: string;
  payload: { accountNumber?: string; amount?: string; referenceId?: string };
  requestedAt: string;
  requestedBy: { fullName: string; role: string };
};

function money(value?: string | number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 2,
  }).format(Number(value || 0));
}

export default function ApprovalsPage() {
  const [rows, setRows] = useState<Approval[]>([]);
  const [loading, setLoading] = useState(false);
  const [note, setNote] = useState("");
  const [selected, setSelected] = useState<Approval | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const load = async () => {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<Approval[]>("/admin/approvals", { params: { status: "PENDING" } });
      setRows(Array.isArray(data) ? data : []);
    } catch {
      setError("复核任务加载失败，请刷新后重试。");
      message.error("复核任务加载失败");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const decide = async (decision: "APPROVED" | "REJECTED") => {
    if (!selected || submitting) return;
    setSubmitting(true);
    try {
      await api.post(`/admin/approvals/${selected.id}/decision`, { decision, note });
      message.success(decision === "APPROVED" ? "已批准并执行" : "已拒绝");
      setSelected(null);
      setNote("");
      await load();
    } catch (e: any) {
      message.error(e.response?.data?.message || "操作失败");
    } finally {
      setSubmitting(false);
    }
  };

  const creditCount = useMemo(() => rows.filter((row) => row.action.includes("CREDIT")).length, [rows]);
  const debitCount = useMemo(() => rows.length - creditCount, [rows, creditCount]);

  const columns: ColumnsType<Approval> = [
    {
      title: "类型",
      dataIndex: "action",
      width: 120,
      render: (value: string) => (
        <Tag color={value.includes("CREDIT") ? "green" : "orange"}>
          {value.includes("CREDIT") ? "账户入金" : "账户扣款"}
        </Tag>
      ),
    },
    { title: "账户", width: 160, render: (_, row) => row.payload.accountNumber || "-" },
    {
      title: "金额",
      width: 140,
      align: "right",
      render: (_, row) => <Text strong>{money(row.payload.amount)}</Text>,
    },
    { title: "业务流水号", width: 180, render: (_, row) => row.payload.referenceId || "-" },
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
      render: (value: string) => new Date(value).toLocaleString("zh-CN"),
    },
    {
      title: "操作",
      fixed: "right",
      width: 120,
      render: (_, row) => (
        <Button
          type="primary"
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
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          eyebrow="ADMIN CONTROL"
          title="余额调整复核（超管）"
          description="仅用于超级管理员发起的余额调整申请。财务日常上下分/上分订单为单人确认，不走本页。申请人与批准人必须是不同员工。"
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()}>
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

        {error && (
          <Alert type="error" showIcon title={error} action={<Button onClick={() => void load()}>重试</Button>} />
        )}

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

        <Card>
          <Table
            rowKey="id"
            loading={loading}
            dataSource={rows}
            columns={columns}
            scroll={{ x: 1100 }}
            pagination={{ pageSize: 20, showTotal: (total) => `共 ${total} 条待复核` }}
          />
        </Card>
      </Space>

      <Modal
        title="独立复核确认"
        open={!!selected}
        onCancel={() => !submitting && setSelected(null)}
        footer={
          <Space>
            <Button danger icon={<CloseOutlined />} loading={submitting} onClick={() => void decide("REJECTED")}>
              拒绝
            </Button>
            <Button type="primary" icon={<CheckOutlined />} loading={submitting} onClick={() => void decide("APPROVED")}>
              批准并执行
            </Button>
          </Space>
        }
      >
        {selected && (
          <Space orientation="vertical" size={8} style={{ width: "100%" }}>
            <Text>类型：{selected.action.includes("CREDIT") ? "账户入金" : "账户扣款"}</Text>
            <Text>账户：{selected.payload.accountNumber || "-"}</Text>
            <Text>金额：{money(selected.payload.amount)}</Text>
            <Text>流水号：{selected.payload.referenceId || "-"}</Text>
            <Text type="secondary">
              发起人：{selected.requestedBy.fullName}（{selected.requestedBy.role}）
            </Text>
            {selected.reason ? <Text type="secondary">申请原因：{selected.reason}</Text> : null}
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
      </Modal>
    </AdminShell>
  );
}
