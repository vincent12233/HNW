"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Input, Select, Space, Table, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import { api, getApiErrorMessage } from "@/lib/api";
import { LOADED_FILTER_CAPTION, filterLoadedRows, maskOpsPhone } from "@/lib/ops-directory";
import { formatOpsDateTime } from "@/lib/ops-format";
import { UNAVAILABLE } from "@/lib/ops-governance";

const { Text } = Typography;

type TransactionRecord = {
  id: string;
  type: string;
  status: string;
  amount: string;
  balanceBefore: string;
  balanceAfter: string;
  referenceId?: string | null;
  note?: string | null;
  createdAt: string;
  account: {
    accountNumber: string;
    user: {
      customerNo?: string | null;
      fullName: string;
      phone?: string | null;
    };
  };
  createdBy?: {
    fullName?: string | null;
    role?: string | null;
  } | null;
};

type TransactionResponse = {
  data: TransactionRecord[];
  pagination: {
    total: number;
    page: number;
    pageSize: number;
  };
};

const typeLabels: Record<string, string> = {
  ADMIN_CREDIT: "财务上分",
  ADMIN_DEBIT: "后台扣款",
  WITHDRAWAL: "提现",
  TRADE_SETTLEMENT: "交易结算",
  IPO_REPAYMENT: "IPO 还款",
  OTC_SETTLEMENT: "OTC 结算",
};

export default function TransactionsPage() {
  const [records, setRecords] = useState<TransactionRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [type, setType] = useState<string | undefined>();
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const loadRecords = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<TransactionResponse>("/admin/accounts/transactions", {
        params: {
          page,
          pageSize,
          type,
        },
      });
      const rows = Array.isArray(response.data.data) ? response.data.data : [];
      setRecords(rows);
      setTotal(Number(response.data.pagination?.total ?? rows.length));
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "资金流水加载失败"));
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, type]);

  useEffect(() => {
    void loadRecords();
  }, [loadRecords]);

  const filteredRecords = useMemo(
    () =>
      filterLoadedRows(records, keyword, (record) => [
        record.account.user.customerNo,
        record.account.user.fullName,
        maskOpsPhone(record.account.user.phone, ""),
        record.account.accountNumber,
        record.referenceId,
        record.note,
        record.type,
        record.status,
      ]),
    [keyword, records],
  );

  const columns: ColumnsType<TransactionRecord> = [
    {
      title: "客户",
      fixed: "left",
      width: 250,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.account.user.fullName || "未命名客户"}</Text>
          <Text type="secondary">
            {record.account.user.customerNo || UNAVAILABLE} / {maskOpsPhone(record.account.user.phone)}
          </Text>
        </Space>
      ),
    },
    {
      title: "交易账号",
      width: 170,
      render: (_, record) => <span className="ops-id">{record.account.accountNumber || UNAVAILABLE}</span>,
    },
    {
      title: "类型",
      dataIndex: "type",
      width: 150,
      render: (value: string) => <OpsStatusTag code={value} label={typeLabels[value] || value || UNAVAILABLE} />,
    },
    {
      title: "金额",
      dataIndex: "amount",
      width: 150,
      align: "right",
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "变动前",
      dataIndex: "balanceBefore",
      width: 150,
      align: "right",
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "变动后",
      dataIndex: "balanceAfter",
      width: 150,
      align: "right",
      render: (value) => <OpsMoney value={value} />,
    },
    {
      title: "流水号",
      dataIndex: "referenceId",
      width: 190,
      render: (value) => value || UNAVAILABLE,
    },
    {
      title: "操作员",
      width: 150,
      render: (_, record) => record.createdBy?.fullName || record.createdBy?.role || UNAVAILABLE,
    },
    {
      title: "时间",
      dataIndex: "createdAt",
      width: 180,
      render: (value: string) => formatOpsDateTime(value),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          eyebrow="SETTLEMENT"
          title="资金流水"
          crumbs={[{ title: "资金查询" }, { title: "资金流水" }]}
          description="查看客户账户的上分、提现、交易结算和系统资金变动。本页使用 GET /admin/accounts/transactions 的真实分页（每页最多 100 条），不是全量流水。关键字筛选只作用于当前页已加载结果。"
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void loadRecords()} aria-label="刷新资金流水">
              查询
            </Button>
          }
        />

        {error ? <OpsErrorState title={error} onRetry={() => void loadRecords()} /> : null}

        <Space wrap>
          <Input
            allowClear
            prefix={<SearchOutlined aria-hidden />}
            placeholder="搜索已加载的客户、脱敏手机号、交易账号、客户编号、流水号"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            aria-label="搜索已加载资金流水"
            style={{ width: 360, maxWidth: "100%" }}
          />
          <Select
            allowClear
            placeholder="流水类型"
            value={type}
            aria-label="按流水类型筛选"
            onChange={(value) => {
              setType(value);
              setPage(1);
            }}
            style={{ width: 220 }}
            options={[
              { value: "ADMIN_CREDIT", label: "财务上分" },
              { value: "WITHDRAWAL", label: "提现" },
              { value: "TRADE_SETTLEMENT", label: "交易结算" },
              { value: "IPO_REPAYMENT", label: "IPO 还款" },
              { value: "OTC_SETTLEMENT", label: "OTC 结算" },
              { value: "ADMIN_DEBIT", label: "后台扣款" },
            ]}
          />
        </Space>
        <Text type="secondary" className="ops-loaded-filter-caption">
          {LOADED_FILTER_CAPTION} 服务端共 {total} 条，当前页 {records.length} 条。
        </Text>

        <Table<TransactionRecord>
          rowKey="id"
          className="ops-directory-table"
          columns={columns}
          dataSource={filteredRecords}
          loading={loading}
          scroll={{ x: 1540 }}
          pagination={{
            current: page,
            pageSize,
            total,
            showSizeChanger: true,
            pageSizeOptions: ["10", "20", "50", "100"],
            showTotal: (count) => `服务端共 ${count} 条`,
            onChange: (nextPage, nextSize) => {
              setPage(nextPage);
              setPageSize(nextSize);
            },
          }}
          locale={{
            emptyText: (
              <OpsEmpty
                description={loading ? "正在加载资金流水" : "当前页没有资金流水。"}
                onRetry={loading ? undefined : () => void loadRecords()}
              />
            ),
          }}
        />
      </Space>
    </AdminShell>
  );
}
