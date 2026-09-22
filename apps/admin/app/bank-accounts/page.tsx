"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Input, Space, Table, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import { api, getApiErrorMessage } from "@/lib/api";
import { maskBankAccount, maskIfsc, maskOpsPhone } from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";

const { Text } = Typography;

type BankAccount = {
  id: string;
  bankName: string;
  accountHolder: string;
  accountNumber: string;
  ifscCode: string;
  isPrimary: boolean;
  createdAt: string;
  user: { fullName: string; phone?: string; customerNo?: string };
};

export default function BankAccountsPage() {
  const [rows, setRows] = useState<BankAccount[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<BankAccount[]>("/admin/bank-accounts");
      setRows(Array.isArray(response.data) ? response.data : []);
    } catch (e: unknown) {
      setError(getApiErrorMessage(e, "银行账户加载失败"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  const data = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter((row) =>
      [
        row.bankName,
        row.accountHolder,
        maskBankAccount(row.accountNumber, ""),
        maskIfsc(row.ifscCode, ""),
        row.user.fullName,
        maskOpsPhone(row.user.phone, ""),
        row.user.customerNo,
      ].some((value) => String(value ?? "").toLowerCase().includes(q)),
    );
  }, [query, rows]);

  const primaryCount = useMemo(() => rows.filter((row) => row.isPrimary).length, [rows]);

  const columns: ColumnsType<BankAccount> = [
    {
      title: "客户",
      width: 220,
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{row.user.fullName}</Text>
          <Text type="secondary">
            {row.user.customerNo || "Unavailable"} / {maskOpsPhone(row.user.phone)}
          </Text>
        </Space>
      ),
    },
    { title: "开户名", dataIndex: "accountHolder", width: 160 },
    { title: "银行", dataIndex: "bankName", width: 160 },
    {
      title: "账户",
      dataIndex: "accountNumber",
      width: 180,
      render: (value: string) => <span className="ops-id">{maskBankAccount(value)}</span>,
    },
    {
      title: "IFSC",
      dataIndex: "ifscCode",
      width: 130,
      render: (value: string) => maskIfsc(value),
    },
    {
      title: "状态",
      width: 120,
      render: (_, row) => (
        <OpsStatusTag code={row.isPrimary ? "ACTIVE" : "PENDING"} label={row.isPrimary ? "主要账户" : "已添加"} />
      ),
    },
    {
      title: "添加时间",
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
          title="客户银行账户"
          crumbs={[{ title: "资金" }, { title: "银行账户" }]}
          description="本页只读展示客户已保存的银行资料，用于提现核对。列表默认脱敏，不提供完整账号复制，也不表示银行已完成验证。"
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()} aria-label="刷新银行账户">
              刷新
            </Button>
          }
        />

        <div className="ops-stat-strip">
          <div className="ops-stat-pill">
            <span className="label">已加载账户</span>
            <span className="value">{rows.length}</span>
          </div>
          <div className="ops-stat-pill">
            <span className="label">主要账户</span>
            <span className="value">{primaryCount}</span>
          </div>
          <div className="ops-stat-pill">
            <span className="label">当前筛选</span>
            <span className="value">{data.length}</span>
          </div>
        </div>

        {error ? <OpsErrorState title={error} onRetry={() => void load()} /> : null}

        <Input
          allowClear
          prefix={<SearchOutlined aria-hidden />}
          placeholder="搜索已加载的客户、银行或脱敏账号"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          aria-label="搜索已加载的银行账户"
          style={{ width: 380, maxWidth: "100%" }}
        />
        <Table
          rowKey="id"
          className="ops-directory-table"
          columns={columns}
          dataSource={data}
          loading={loading}
          scroll={{ x: 1140 }}
          pagination={OPS_TABLE_PAGINATION}
          locale={{
            emptyText: (
              <OpsEmpty
                description={loading ? "正在加载银行账户" : "当前没有已加载的银行账户。"}
                onRetry={loading ? undefined : () => void load()}
              />
            ),
          }}
        />
      </Space>
    </AdminShell>
  );
}
