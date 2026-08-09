"use client";

import { BankOutlined, CreditCardOutlined, DollarOutlined, ReloadOutlined, WarningOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Col, Row, Space, Statistic, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type AccountRecord = {
  id: string;
  accountNumber: string;
  balances: { cashBalance: string; frozenBalance: string; holdingsMarketValue: string; totalAsset: string };
  user: { customerNo?: string | null; fullName: string; phone?: string | null; status: string };
};

type AccountResponse = { data: AccountRecord[] };

type TransactionRecord = {
  id: string;
  type: string;
  amount: string | number;
  status: string;
  referenceId?: string | null;
  createdAt: string;
  account: { accountNumber: string; user: { customerNo?: string | null; fullName: string; phone?: string | null } };
};

type TransactionResponse = { data: TransactionRecord[] };

type WithdrawalRecord = {
  id: string;
  orderNo?: string | null;
  amount: string | number;
  status: string;
  account: { accountNumber: string; user: { customerNo?: string | null; fullName: string; phone?: string | null } };
};

type LoanRecord = {
  id: string;
  orderNo: string;
  outstandingAmount: string | number;
  status: string;
  account: { accountNumber: string; user: { customerNo?: string | null; fullName: string; phone?: string | null } };
};

type IpoDebt = {
  id: string;
  outstandingAmount: string | number;
  status: string;
  account: { accountNumber: string; user: { customerNo?: string | null; fullName: string; phone?: string | null } };
  ipo: { symbol: string; companyName: string };
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 }).format(Number(value ?? 0));
}

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export default function FinanceOverviewPage() {
  const [accounts, setAccounts] = useState<AccountRecord[]>([]);
  const [transactions, setTransactions] = useState<TransactionRecord[]>([]);
  const [withdrawals, setWithdrawals] = useState<WithdrawalRecord[]>([]);
  const [loans, setLoans] = useState<LoanRecord[]>([]);
  const [ipoDebts, setIpoDebts] = useState<IpoDebt[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadData() {
    setLoading(true);
    setError("");
    try {
      const [accountResponse, transactionResponse, withdrawalResponse, loanResponse, ipoDebtResponse] = await Promise.all([
        api.get<AccountResponse>("/admin/accounts", { params: { page: 1, pageSize: 100 } }),
        api.get<TransactionResponse>("/admin/accounts/transactions", { params: { page: 1, pageSize: 12 } }),
        api.get<WithdrawalRecord[]>("/withdrawal/pending"),
        api.get<LoanRecord[]>("/loans"),
        api.get<IpoDebt[]>("/admin/ipo/debts"),
      ]);

      setAccounts(Array.isArray(accountResponse.data.data) ? accountResponse.data.data : []);
      setTransactions(Array.isArray(transactionResponse.data.data) ? transactionResponse.data.data : []);
      setWithdrawals(Array.isArray(withdrawalResponse.data) ? withdrawalResponse.data : []);
      setLoans(Array.isArray(loanResponse.data) ? loanResponse.data : []);
      setIpoDebts(Array.isArray(ipoDebtResponse.data) ? ipoDebtResponse.data : []);
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(Array.isArray(responseMessage) ? responseMessage.join("，") : responseMessage || "资金总览加载失败");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadData();
  }, []);

  const metrics = useMemo(() => {
    const totalAssets = accounts.reduce((sum, item) => sum + Number(item.balances.totalAsset ?? 0), 0);
    const totalCash = accounts.reduce((sum, item) => sum + Number(item.balances.cashBalance ?? 0), 0);
    const pendingWithdrawalAmount = withdrawals.reduce((sum, item) => sum + Number(item.amount ?? 0), 0);
    const loanOutstanding = loans.reduce((sum, item) => sum + Number(item.outstandingAmount ?? 0), 0);
    const ipoOutstanding = ipoDebts.reduce((sum, item) => sum + Number(item.outstandingAmount ?? 0), 0);

    return { totalAssets, totalCash, pendingWithdrawalAmount, loanOutstanding, ipoOutstanding };
  }, [accounts, withdrawals, loans, ipoDebts]);

  const transactionColumns: ColumnsType<TransactionRecord> = [
    { title: "客户", width: 230, render: (_, row) => <Space orientation="vertical" size={0}><Text strong>{row.account.user.fullName}</Text><Text type="secondary">{row.account.user.customerNo || "-"} / {row.account.accountNumber}</Text></Space> },
    { title: "类型", dataIndex: "type", width: 150, render: (value) => <Tag>{value}</Tag> },
    { title: "金额", dataIndex: "amount", width: 140, align: "right", render: formatMoney },
    { title: "状态", dataIndex: "status", width: 120 },
    { title: "流水号", dataIndex: "referenceId", width: 180, render: (value) => value || "-" },
    { title: "时间", dataIndex: "createdAt", width: 180, render: formatDate },
  ];

  const debtColumns: ColumnsType<IpoDebt | LoanRecord> = [
    { title: "客户", width: 230, render: (_, row) => <Space orientation="vertical" size={0}><Text strong>{row.account.user.fullName}</Text><Text type="secondary">{row.account.user.customerNo || "-"} / {row.account.accountNumber}</Text></Space> },
    { title: "项目", width: 220, render: (_, row) => "ipo" in row ? `${row.ipo.symbol} / ${row.ipo.companyName}` : `贷款 ${row.orderNo}` },
    { title: "未结金额", dataIndex: "outstandingAmount", width: 150, align: "right", render: (value) => <Text type={Number(value) > 0 ? "danger" : undefined}>{formatMoney(value)}</Text> },
    { title: "状态", dataIndex: "status", width: 130, render: (value) => <Tag color={value === "PAID" || value === "REPAID" ? "green" : "orange"}>{value}</Tag> },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>资金总览</Title>
          <Paragraph type="secondary">集中查看账户资产、提现待审、贷款未还、IPO 欠款和最近资金流水。</Paragraph>
        </div>
        {error && <Alert type="error" title={error} showIcon />}
        <Row gutter={[16, 16]}>
          <Col xs={24} md={8} xl={5}><Card><Statistic title="客户总资产" value={metrics.totalAssets} prefix={<DollarOutlined />} formatter={(value) => formatMoney(value as number)} /></Card></Col>
          <Col xs={24} md={8} xl={5}><Card><Statistic title="客户现金" value={metrics.totalCash} prefix={<CreditCardOutlined />} formatter={(value) => formatMoney(value as number)} /></Card></Col>
          <Col xs={24} md={8} xl={5}><Card><Statistic title="待审核提现" value={metrics.pendingWithdrawalAmount} prefix={<BankOutlined />} formatter={(value) => formatMoney(value as number)} /></Card></Col>
          <Col xs={24} md={8} xl={5}><Card><Statistic title="贷款未还" value={metrics.loanOutstanding} prefix={<WarningOutlined />} formatter={(value) => formatMoney(value as number)} /></Card></Col>
          <Col xs={24} md={8} xl={4}><Card><Statistic title="IPO 欠款" value={metrics.ipoOutstanding} formatter={(value) => formatMoney(value as number)} /></Card></Col>
        </Row>
        <Card title="最近资金流水" extra={<Button icon={<ReloadOutlined />} loading={loading} onClick={loadData}>刷新</Button>}>
          <Table<TransactionRecord> rowKey="id" columns={transactionColumns} dataSource={transactions} loading={loading} scroll={{ x: 1100 }} pagination={false} />
        </Card>
        <Card title="未结资金事项">
          <Table<IpoDebt | LoanRecord> rowKey="id" columns={debtColumns} dataSource={[...ipoDebts.filter((item) => item.status !== "PAID"), ...loans.filter((item) => !["REPAID", "REJECTED"].includes(item.status))]} loading={loading} scroll={{ x: 900 }} pagination={{ pageSize: 10 }} />
        </Card>
      </Space>
    </AdminShell>
  );
}
