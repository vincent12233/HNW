"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Input, Select, Space, Table, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";
import { filterLoadedRows, maskOpsPhone, maskedPayoutLabel } from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { FUNDING_COPY } from "@/lib/ops-funding";

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
    id: string;
    accountNumber: string;
    currency: string;
    user: {
      id: string;
      customerNo?: string | null;
      fullName: string;
      phone?: string | null;
      status: string;
    };
  };
};

export default function BusinessWithdrawalsPage() {
  const [records, setRecords] = useState<WithdrawalRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [statusFilter, setStatusFilter] = useState<"ALL" | "PENDING" | "APPROVED" | "REJECTED">("ALL");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadRecords() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<WithdrawalRecord[]>("/business/my-withdrawals");
      setRecords(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "提现记录加载失败");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadRecords();
  }, []);

  const filteredRecords = useMemo(() => {
    const byStatus = statusFilter === "ALL" ? records : records.filter((record) => record.status === statusFilter);
    return filterLoadedRows(byStatus, keyword, (record) => [
      record.orderNo,
      record.account.user.customerNo,
      record.account.user.fullName,
      maskOpsPhone(record.account.user.phone, ""),
      record.account.accountNumber,
      record.bankName,
      record.status,
    ]);
  }, [keyword, records, statusFilter]);

  const columns: ColumnsType<WithdrawalRecord> = [
    {
      title: "订单号",
      dataIndex: "orderNo",
      width: 180,
      fixed: "left",
      render: (value) => <Text copyable={{ text: value || "" }}>{value || "—"}</Text>,
    },
    {
      title: "客户",
      key: "customer",
      width: 240,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <span className="ops-wrap-text">{record.account.user.fullName || "未命名客户"}</span>
          <Text type="secondary">
            {record.account.user.customerNo || "—"} · {maskOpsPhone(record.account.user.phone)}
          </Text>
        </Space>
      ),
    },
    { title: "交易账号", key: "tradingAccount", width: 170, render: (_, record) => <span className="ops-id">{record.account.accountNumber}</span> },
    {
      title: "提现金额",
      dataIndex: "amount",
      key: "amount",
      width: 150,
      align: "right",
      render: (value) => <OpsMoney value={value} />,
    },
    { title: "收款信息", key: "payoutMethod", width: 280, render: (_, record) => maskedPayoutLabel(record) },
    {
      title: "状态",
      dataIndex: "status",
      key: "status",
      width: 130,
      render: (value: string) => <OpsStatusTag code={value} label={value === "PENDING" ? "待财务审核" : undefined} />,
    },
    { title: "备注", dataIndex: "note", key: "note", width: 220, render: (value) => <span className="ops-wrap-text">{value || "—"}</span> },
    { title: "申请时间", dataIndex: "createdAt", key: "createdAt", width: 180, render: (value: string) => formatOpsDateTime(value) },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={FUNDING_COPY.businessWithdrawalsTitle}
          crumbs={[{ title: "资金" }, { title: FUNDING_COPY.businessWithdrawalsTitle }]}
          description={`这里只显示自己名下客户的提现申请和处理结果，审核由财务后台完成。本页不能通过或拒绝提现。${FUNDING_COPY.withdrawMask} ${FUNDING_COPY.noVipPriority}`}
        />

        {error ? <OpsErrorState title={error} onRetry={loadRecords} /> : null}

        <OpsToolbar extra={<Button icon={<ReloadOutlined />} onClick={loadRecords} loading={loading} aria-label="刷新提现记录">刷新</Button>}>
          <Input
            allowClear
            prefix={<SearchOutlined aria-hidden />}
            placeholder="搜索已加载的订单号、客户编号或交易账号"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            aria-label="搜索已加载的提现记录"
            style={{ width: 420, maxWidth: "100%" }}
          />
          <Select
            value={statusFilter}
            style={{ width: 160 }}
            aria-label="按提现状态筛选"
            onChange={(value: "ALL" | "PENDING" | "APPROVED" | "REJECTED") => setStatusFilter(value)}
            options={[
              { value: "ALL", label: "全部状态" },
              { value: "PENDING", label: "待审核" },
              { value: "APPROVED", label: "已通过" },
              { value: "REJECTED", label: "已拒绝" },
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
          scroll={{ x: 1580 }}
          pagination={OPS_TABLE_PAGINATION}
          locale={{ emptyText: <OpsEmpty description={loading ? "正在加载提现记录" : "当前没有提现记录。"} onRetry={loading ? undefined : loadRecords} /> }}
        />
      </Space>
    </AdminShell>
  );
}
