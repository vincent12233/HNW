"use client";

import { BankOutlined, CreditCardOutlined, DollarOutlined, MinusCircleOutlined, PlusCircleOutlined, ReloadOutlined, WarningOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Col, Form, Input, InputNumber, Modal, Row, Space, Statistic, Table, Tag, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, formatCreditSuccessMessage, getApiErrorMessage } from '@/lib/api';

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
  const [form] = Form.useForm();
  const [accounts, setAccounts] = useState<AccountRecord[]>([]);
  const [transactions, setTransactions] = useState<TransactionRecord[]>([]);
  const [withdrawals, setWithdrawals] = useState<WithdrawalRecord[]>([]);
  const [loans, setLoans] = useState<LoanRecord[]>([]);
  const [ipoDebts, setIpoDebts] = useState<IpoDebt[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [adjustment, setAdjustment] = useState<{ accountNumber: string; direction: "credit" | "debit" } | null>(null);
  const [submitting, setSubmitting] = useState(false);

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
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "资金总览加载失败");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadData();
  }, []);

  async function submitAdjustment(values: { amount: number; referenceId: string; note?: string }) {
    if (!adjustment) return;
    setSubmitting(true);
    try {
      const { data } = await api.post(
        `/admin/accounts/${adjustment.accountNumber}/${adjustment.direction}`,
        {
          amount: Number(values.amount).toFixed(2),
          referenceId: values.referenceId.trim(),
          note: values.note?.trim(),
        },
      );
      message.success(
        adjustment.direction === "credit"
          ? formatCreditSuccessMessage(data, "上分订单已创建并入账")
          : "下分已执行并写入流水",
      );
      setAdjustment(null);
      form.resetFields();
      await loadData();
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "资金调整提交失败"));
    } finally {
      setSubmitting(false);
    }
  }

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

  const accountColumns: ColumnsType<AccountRecord> = [
    { title: "客户", width: 220, render: (_, row) => <Space orientation="vertical" size={0}><Text strong>{row.user.fullName}</Text><Text type="secondary">{row.user.customerNo || "-"} / {row.user.phone || "-"}</Text></Space> },
    { title: "账户号", dataIndex: "accountNumber", width: 170 },
    { title: "现金余额", width: 150, align: "right", render: (_, row) => formatMoney(row.balances.cashBalance) },
    { title: "冻结金额", width: 150, align: "right", render: (_, row) => formatMoney(row.balances.frozenBalance) },
    { title: "总资产", width: 150, align: "right", render: (_, row) => formatMoney(row.balances.totalAsset) },
    { title: "操作", width: 210, fixed: "right", render: (_, row) => <Space><Button icon={<PlusCircleOutlined />} onClick={() => setAdjustment({ accountNumber: row.accountNumber, direction: "credit" })}>上分</Button><Button danger icon={<MinusCircleOutlined />} onClick={() => setAdjustment({ accountNumber: row.accountNumber, direction: "debit" })}>扣款</Button></Space> },
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
          <Title level={2}>上下分</Title>
          <Paragraph type="secondary">
            客户存款完成后，财务按交易账号单人创建上分或下分订单，确认后立即入账并留痕。无需双人复核。提现仍由客户在 APP 发起后走「提现审核」。
          </Paragraph>
        </div>
        {error && <Alert type="error" title={error} showIcon />}
        <Row gutter={[16, 16]}>
          <Col xs={24} md={8} xl={5}><Card><Statistic title="客户总资产" value={metrics.totalAssets} prefix={<DollarOutlined />} formatter={(value) => formatMoney(value as number)} /></Card></Col>
          <Col xs={24} md={8} xl={5}><Card><Statistic title="客户现金" value={metrics.totalCash} prefix={<CreditCardOutlined />} formatter={(value) => formatMoney(value as number)} /></Card></Col>
          <Col xs={24} md={8} xl={5}><Card><Statistic title="待审核提现" value={metrics.pendingWithdrawalAmount} prefix={<BankOutlined />} formatter={(value) => formatMoney(value as number)} /></Card></Col>
          <Col xs={24} md={8} xl={5}><Card><Statistic title="贷款未还" value={metrics.loanOutstanding} prefix={<WarningOutlined />} formatter={(value) => formatMoney(value as number)} /></Card></Col>
          <Col xs={24} md={8} xl={4}><Card><Statistic title="IPO 欠款" value={metrics.ipoOutstanding} formatter={(value) => formatMoney(value as number)} /></Card></Col>
        </Row>
        <Card title="客户账户" extra={<Text type="secondary">当前财务员工单人确认后立即执行并留痕，无需复核</Text>}>
          <Table<AccountRecord> rowKey="id" columns={accountColumns} dataSource={accounts} loading={loading} scroll={{ x: 1100 }} pagination={{ pageSize: 10 }} />
        </Card>
        <Card title="最近资金流水" extra={<Button icon={<ReloadOutlined />} loading={loading} onClick={loadData}>刷新</Button>}>
          <Table<TransactionRecord> rowKey="id" columns={transactionColumns} dataSource={transactions} loading={loading} scroll={{ x: 1100 }} pagination={false} />
        </Card>
        <Card title="未结资金事项">
          <Table<IpoDebt | LoanRecord> rowKey="id" columns={debtColumns} dataSource={[...ipoDebts.filter((item) => item.status !== "PAID"), ...loans.filter((item) => !["REPAID", "REJECTED"].includes(item.status))]} loading={loading} scroll={{ x: 900 }} pagination={{ pageSize: 10 }} />
        </Card>
      </Space>
      <Modal title={`${adjustment?.direction === "credit" ? "创建上分订单" : "账户下分"} · ${adjustment?.accountNumber || ""}`} open={Boolean(adjustment)} onCancel={() => { setAdjustment(null); form.resetFields(); }} onOk={() => form.submit()} confirmLoading={submitting} okText={adjustment?.direction === "credit" ? "确认创建并上分" : "确认下分"} destroyOnHidden>
        <Form form={form} layout="vertical" onFinish={submitAdjustment}>
          <Form.Item name="amount" label="调整金额" rules={[{ required: true, message: "请输入金额" }]}><InputNumber min={0.01} precision={2} style={{ width: "100%" }} prefix="₹" /></Form.Item>
          <Form.Item name="referenceId" label="付款流水号" rules={[{ required: true, message: "请输入唯一流水号" }, { min: 8, message: "流水号至少 8 个字符" }]}><Input placeholder="银行流水或内部工单号" /></Form.Item>
          <Form.Item name="note" label="调整说明" rules={[{ required: true, message: "请输入调整原因" }]}><Input.TextArea rows={3} placeholder="说明资金来源或扣款原因" /></Form.Item>
        </Form>
      </Modal>
    </AdminShell>
  );
}
