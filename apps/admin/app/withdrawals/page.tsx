"use client";

import { CheckOutlined, CloseOutlined, ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import {
  Button,
  Input,
  Select,
  Space,
  Table,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";
import { FUNDING_COPY } from "@/lib/ops-funding";
import { filterLoadedRows, maskOpsPhone, maskedPayoutLabel } from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";

const { Text } = Typography;

type WithdrawalRecord = {
  id: string;
  orderNo?: string | null;
  amount: string | number;
  bankName?: string | null;
  accountNumber?: string | null;
  ifscCode?: string | null;
  upiId?: string | null;
  note?: string | null;
  status: string;
  createdAt: string;
  account: {
    accountNumber: string;
    user: {
      id: string;
      fullName: string;
      phone?: string | null;
      customerNo?: string | null;
    };
  };
};

type StatusFilter = "PENDING" | "APPROVED" | "REJECTED" | "ALL";

function payoutMethod(record: WithdrawalRecord) {
  return maskedPayoutLabel(record);
}

export default function WithdrawalsPage() {
  const [records, setRecords] = useState<WithdrawalRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("PENDING");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [rejecting, setRejecting] = useState<WithdrawalRecord | null>(null);
  const [approving, setApproving] = useState<WithdrawalRecord | null>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [submittingId, setSubmittingId] = useState("");
  const submitting = useRef(false);

  const loadRecords = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const response =
        statusFilter === "PENDING"
          ? await api.get<WithdrawalRecord[]>("/withdrawal/pending")
          : await api.get<WithdrawalRecord[]>("/withdrawal/history", {
              params: { status: statusFilter },
            });
      setRecords(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "提现申请加载失败",
      );
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => {
    void loadRecords();
  }, [loadRecords]);

  const filteredRecords = useMemo(
    () =>
      filterLoadedRows(records, keyword, (record) => [
        record.orderNo,
        record.account.user.customerNo,
        record.account.user.fullName,
        maskOpsPhone(record.account.user.phone, ""),
        record.account.accountNumber,
        record.status,
        record.bankName,
      ]),
    [keyword, records],
  );

  async function approve(record: WithdrawalRecord) {
    if (submitting.current || loading || error) return;
    submitting.current = true;
    setSubmittingId(record.id);
    try {
      await api.patch(`/withdrawal/${record.id}/approve`);
      message.success("提现已通过");
      setApproving(null);
      await loadRecords();
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      message.error(responseMessage || "提现通过失败",
      );
    } finally {
      submitting.current = false;
      setSubmittingId("");
    }
  }

  async function reject() {
    if (!rejecting) return;
    if (submitting.current || loading || error) return;
    if (rejectNote.trim().length < 3) {
      message.error("请输入至少 3 个字符的拒绝原因");
      return;
    }

    submitting.current = true;
    setSubmittingId(rejecting.id);
    try {
      await api.patch(`/withdrawal/${rejecting.id}/reject`, {
        note: rejectNote,
      });
      message.success("提现已拒绝");
      setRejecting(null);
      setRejectNote("");
      await loadRecords();
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      message.error(responseMessage || "提现拒绝失败",
      );
    } finally {
      submitting.current = false;
      setSubmittingId("");
    }
  }

  const showActions = statusFilter === "PENDING";

  const columns: ColumnsType<WithdrawalRecord> = [
    {
      title: "订单号",
      dataIndex: "orderNo",
      fixed: "left",
      width: 180,
      render: (value) => <Text copyable>{value || "-"}</Text>,
    },
    {
      title: "客户",
      width: 240,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.account.user.fullName || "未命名客户"}</Text>
          <Text type="secondary">
            {record.account.user.customerNo || "—"} · {maskOpsPhone(record.account.user.phone)}
          </Text>
        </Space>
      ),
    },
    { title: "交易账号", width: 170, render: (_, record) => <span className="ops-id">{record.account.accountNumber}</span> },
    {
      title: "金额",
      width: 150,
      align: "right",
      render: (_, record) => <OpsMoney value={record.amount} />,
    },
    { title: "收款信息", width: 280, render: (_, record) => payoutMethod(record) },
    { title: "备注", dataIndex: "note", width: 180, render: (value) => <span className="ops-wrap-text">{value || "—"}</span> },
    {
      title: "状态",
      dataIndex: "status",
      width: 110,
      render: (value: string) => <OpsStatusTag code={value} />,
    },
    { title: "申请时间", dataIndex: "createdAt", width: 180, render: (value: string) => formatOpsDateTime(value) },
    ...(showActions
      ? [{
          title: "操作",
          fixed: "right" as const,
          width: 180,
          render: (_: unknown, record: WithdrawalRecord) => (
            <Space>
              <Button
                type="primary"
                size="small"
                icon={<CheckOutlined />}
                loading={submittingId === record.id}
                disabled={!!submittingId}
                aria-label={`通过 ${record.account.user.fullName} 的提现`}
                onClick={() => setApproving(record)}
              >
                通过
              </Button>
              <Button danger size="small" icon={<CloseOutlined />} disabled={!!submittingId} aria-label={`拒绝 ${record.account.user.fullName} 的提现`} onClick={() => setRejecting(record)}>
                拒绝
              </Button>
            </Space>
          ),
        }]
      : []),
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={FUNDING_COPY.withdrawalsTitle}
          crumbs={[{ title: "资金" }, { title: FUNDING_COPY.withdrawalsTitle }]}
          description={`客户在 APP 发起提现后，财务核对收款信息并单人通过或拒绝。${FUNDING_COPY.withdrawMask} ${FUNDING_COPY.noVipPriority}`}
        />

        {error ? <OpsErrorState title={error} onRetry={loadRecords} /> : null}

        <OpsToolbar
          extra={<Button icon={<ReloadOutlined />} loading={loading} onClick={loadRecords} aria-label="刷新提现列表">刷新</Button>}
        >
          <Input
            allowClear
            prefix={<SearchOutlined aria-hidden />}
            placeholder="搜索已加载的订单号、客户编号或交易账号"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            aria-label="搜索已加载的提现申请"
            style={{ width: 420, maxWidth: "100%" }}
          />
          <Select
            value={statusFilter}
            style={{ width: 160 }}
            aria-label="按提现状态筛选"
            onChange={(value: StatusFilter) => setStatusFilter(value)}
            options={[
              { value: "PENDING", label: "待审核" },
              { value: "APPROVED", label: "已通过" },
              { value: "REJECTED", label: "已拒绝" },
              { value: "ALL", label: "全部" },
            ]}
          />
        </OpsToolbar>
        <Text type="secondary">{FUNDING_COPY.loadedFilter}</Text>

        <Table<WithdrawalRecord>
          rowKey="id"
          className="ops-directory-table"
          columns={columns}
          dataSource={filteredRecords}
          loading={loading}
          scroll={{ x: showActions ? 1540 : 1360 }}
          pagination={OPS_TABLE_PAGINATION}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载提现申请" : "当前没有提现申请。"} onRetry={loading ? undefined : loadRecords} /> }}
        />
      </Space>

      <OpsModal
        title="确认通过提现"
        open={!!approving}
        onCancel={() => { if (!submitting.current) setApproving(null); }}
        onOk={() => approving && approve(approving)}
        confirmLoading={!!submittingId}
        okText="提交到服务器"
        cancelText="返回"
        zIndex={2100}
      >
        {approving ? (
          <Space orientation="vertical">
            <Text>客户 {approving.account.user.fullName} · 金额 <OpsMoney value={approving.amount} /> · 当前待审核</Text>
            <Text>{payoutMethod(approving)}</Text>
            <Text type="secondary">结果只在服务器成功后刷新。失败时记录仍保留在列表中。</Text>
          </Space>
        ) : null}
      </OpsModal>

      <OpsModal
        title="拒绝提现"
        open={!!rejecting}
        onCancel={() => {
          if (submitting.current) return;
          setRejecting(null);
          setRejectNote("");
        }}
        onOk={reject}
        confirmLoading={!!submittingId}
        okText="确认拒绝"
        cancelText="返回"
        okButtonProps={{ danger: true }}
        zIndex={2100}
      >
        <Input.TextArea
          rows={4}
          value={rejectNote}
          onChange={(event) => setRejectNote(event.target.value)}
          placeholder="请输入拒绝原因"
        />
      </OpsModal>
    </AdminShell>
  );
}
