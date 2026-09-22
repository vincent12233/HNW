"use client";

import { BankOutlined, CreditCardOutlined, DollarOutlined, MinusCircleOutlined, PlusCircleOutlined, ReloadOutlined, WarningOutlined } from "@ant-design/icons";
import { Button, Card, Col, Form, Input, InputNumber, Row, Space, Statistic, Table, Typography, message } from "antd";
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
import { maskOpsPhone } from "@/lib/ops-directory";
import { formatInr, formatOpsDateTime } from "@/lib/ops-format";

const { Text } = Typography;

type AccountRecord = {
  id: string;
  accountNumber: string;
  balances: { cashBalance: string; frozenBalance: string; holdingsMarketValue: string; totalAsset: string };
  user: { customerNo?: string | null; fullName: string; phone?: string | null; status: string };
};

type AccountResponse = {
  data: AccountRecord[];
  page?: number;
  pageSize?: number;
  total?: number;
  totalPages?: number;
};

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

export default function FinanceOverviewPage() {
  const [form] = Form.useForm();
  const [accounts, setAccounts] = useState<AccountRecord[]>([]);
  const [accountPage, setAccountPage] = useState(1);
  const [accountPageSize, setAccountPageSize] = useState(20);
  const [accountTotal, setAccountTotal] = useState(0);
  const [transactions, setTransactions] = useState<TransactionRecord[]>([]);
  const [withdrawals, setWithdrawals] = useState<WithdrawalRecord[]>([]);
  const [loans, setLoans] = useState<LoanRecord[]>([]);
  const [ipoDebts, setIpoDebts] = useState<IpoDebt[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [adjustment, setAdjustment] = useState<{ accountNumber: string; direction: "credit" | "debit" } | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const submittingRef = useRef(false);

  const loadData = useCallback(async (page = accountPage, pageSize = accountPageSize) => {
    setLoading(true);
    setError("");
    try {
      const [accountResponse, transactionResponse, withdrawalResponse, loanResponse, ipoDebtResponse] = await Promise.all([
        api.get<AccountResponse>("/admin/accounts", { params: { page, pageSize } }),
        api.get<TransactionResponse>("/admin/accounts/transactions", { params: { page: 1, pageSize: 12 } }),
        api.get<WithdrawalRecord[]>("/withdrawal/pending"),
        api.get<LoanRecord[]>("/loans"),
        api.get<IpoDebt[]>("/admin/ipo/debts"),
      ]);

      const loadedAccounts = Array.isArray(accountResponse.data.data) ? accountResponse.data.data : [];
      setAccounts(loadedAccounts);
      setAccountPage(accountResponse.data.page || page);
      setAccountPageSize(accountResponse.data.pageSize || pageSize);
      setAccountTotal(Number(accountResponse.data.total ?? loadedAccounts.length));
      setTransactions(Array.isArray(transactionResponse.data.data) ? transactionResponse.data.data : []);
      setWithdrawals(Array.isArray(withdrawalResponse.data) ? withdrawalResponse.data : []);
      setLoans(Array.isArray(loanResponse.data) ? loanResponse.data : []);
      setIpoDebts(Array.isArray(ipoDebtResponse.data) ? ipoDebtResponse.data : []);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "资金总览加载失败"));
    } finally {
      setLoading(false);
    }
  }, [accountPage, accountPageSize]);

  useEffect(() => {
    void loadData(accountPage, accountPageSize);
  }, [accountPage, accountPageSize, loadData]);

  async function submitAdjustment(values: { amount: number; referenceId: string; note?: string }) {
    if (!adjustment || submittingRef.current) return;
    submittingRef.current = true;
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
      await loadData(accountPage, accountPageSize);
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "资金调整提交失败"));
    } finally {
      submittingRef.current = false;
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
    {
      title: "客户",
      width: 230,
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{row.account.user.fullName}</Text>
          <Text type="secondary">
            {row.account.user.customerNo || "Unavailable"} / {maskOpsPhone(row.account.user.phone)}
          </Text>
        </Space>
      ),
    },
    { title: "类型", dataIndex: "type", width: 150, render: (value: string) => <OpsStatusTag code={value} /> },
    { title: "金额", dataIndex: "amount", width: 140, align: "right", render: (value) => <OpsMoney value={value} /> },
    { title: "状态", dataIndex: "status", width: 120, render: (value: string) => <OpsStatusTag code={value} /> },
    { title: "流水号", dataIndex: "referenceId", width: 180, render: (value) => value || "Unavailable" },
    { title: "时间", dataIndex: "createdAt", width: 180, render: (value: string) => formatOpsDateTime(value) },
  ];

  const accountColumns: ColumnsType<AccountRecord> = [
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
    { title: "账户号", dataIndex: "accountNumber", width: 170, render: (value: string) => <span className="ops-id">{value}</span> },
    { title: "现金余额", width: 150, align: "right", render: (_, row) => <OpsMoney value={row.balances.cashBalance} /> },
    { title: "冻结金额", width: 150, align: "right", render: (_, row) => <OpsMoney value={row.balances.frozenBalance} /> },
    { title: "总资产", width: 150, align: "right", render: (_, row) => <OpsMoney value={row.balances.totalAsset} /> },
    {
      title: "操作",
      width: 210,
      fixed: "right",
      render: (_, row) => (
        <Space>
          <Button
            icon={<PlusCircleOutlined />}
            aria-label={`为 ${row.accountNumber} 上分`}
            onClick={() => setAdjustment({ accountNumber: row.accountNumber, direction: "credit" })}
          >
            上分
          </Button>
          <Button
            danger
            icon={<MinusCircleOutlined />}
            aria-label={`为 ${row.accountNumber} 扣款`}
            onClick={() => setAdjustment({ accountNumber: row.accountNumber, direction: "debit" })}
          >
            扣款
          </Button>
        </Space>
      ),
    },
  ];

  const debtColumns: ColumnsType<IpoDebt | LoanRecord> = [
    {
      title: "客户",
      width: 230,
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{row.account.user.fullName}</Text>
          <Text type="secondary">
            {row.account.user.customerNo || "Unavailable"} / {maskOpsPhone(row.account.user.phone)}
          </Text>
        </Space>
      ),
    },
    { title: "项目", width: 220, render: (_, row) => ("ipo" in row ? `${row.ipo.symbol} / ${row.ipo.companyName}` : `贷款 ${row.orderNo}`) },
    {
      title: "未结金额",
      dataIndex: "outstandingAmount",
      width: 150,
      align: "right",
      render: (value) => (
        <Text type={Number(value) > 0 ? "danger" : undefined}>
          <OpsMoney value={value} />
        </Text>
      ),
    },
    { title: "状态", dataIndex: "status", width: 130, render: (value: string) => <OpsStatusTag code={value} /> },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          eyebrow="SETTLEMENT"
          title="上下分"
          crumbs={[{ title: "资金操作" }, { title: "上下分" }]}
          description="客户存款完成后，财务按交易账号单人创建上分或下分订单，确认后立即入账并留痕。无需双人复核。提现仍由客户在 APP 发起后走「提现审核」。账户列表使用 GET /admin/accounts 的真实分页，每页最多 100 条；下方资产数字只统计当前页已加载账户，不是全平台合计。"
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void loadData(accountPage, accountPageSize)} aria-label="刷新资金总览">
              刷新
            </Button>
          }
        />
        {error ? <OpsErrorState title={error} onRetry={() => void loadData(accountPage, accountPageSize)} /> : null}
        <Row gutter={[16, 16]}>
          <Col xs={24} md={8} xl={5}>
            <Card>
              <Statistic title={`当前页账户资产（${accounts.length}/${accountTotal}）`} value={metrics.totalAssets} prefix={<DollarOutlined />} formatter={(value) => formatInr(value as number)} />
            </Card>
          </Col>
          <Col xs={24} md={8} xl={5}>
            <Card>
              <Statistic title="当前页账户现金" value={metrics.totalCash} prefix={<CreditCardOutlined />} formatter={(value) => formatInr(value as number)} />
            </Card>
          </Col>
          <Col xs={24} md={8} xl={5}>
            <Card>
              <Statistic title="待审核提现（当前接口）" value={metrics.pendingWithdrawalAmount} prefix={<BankOutlined />} formatter={(value) => formatInr(value as number)} />
            </Card>
          </Col>
          <Col xs={24} md={8} xl={5}>
            <Card>
              <Statistic title="贷款未还（当前接口）" value={metrics.loanOutstanding} prefix={<WarningOutlined />} formatter={(value) => formatInr(value as number)} />
            </Card>
          </Col>
          <Col xs={24} md={8} xl={4}>
            <Card>
              <Statistic title="IPO 欠款（当前接口）" value={metrics.ipoOutstanding} formatter={(value) => formatInr(value as number)} />
            </Card>
          </Col>
        </Row>
        <Card title="客户账户" extra={<Text type="secondary">当前页样本，不是全量账户。财务员工单人确认后立即执行并留痕，无需复核</Text>}>
          <Table<AccountRecord>
            rowKey="id"
            className="ops-directory-table"
            columns={accountColumns}
            dataSource={accounts}
            loading={loading}
            scroll={{ x: 1100 }}
            pagination={{
              current: accountPage,
              pageSize: accountPageSize,
              total: accountTotal,
              showSizeChanger: true,
              pageSizeOptions: ["10", "20", "50", "100"],
              showTotal: (total) => `服务端共 ${total} 条账户，当前页 ${accounts.length} 条`,
              onChange: (page, pageSize) => {
                setAccountPage(page);
                setAccountPageSize(pageSize);
              },
            }}
            locale={{
              emptyText: (
                <OpsEmpty
                  description={loading ? "正在加载账户" : "当前页没有账户。"}
                  onRetry={loading ? undefined : () => void loadData(accountPage, accountPageSize)}
                />
              ),
            }}
          />
        </Card>
        <Card title="最近资金流水" extra={<Text type="secondary">仅 GET /admin/accounts/transactions 第 1 页 12 条</Text>}>
          <Table<TransactionRecord>
            rowKey="id"
            className="ops-directory-table"
            columns={transactionColumns}
            dataSource={transactions}
            loading={loading}
            scroll={{ x: 1100 }}
            pagination={false}
            locale={{ emptyText: <OpsEmpty description={loading ? "正在加载流水" : "当前没有已加载的资金流水。"} /> }}
          />
        </Card>
        <Card title="未结资金事项">
          <Table<IpoDebt | LoanRecord>
            rowKey="id"
            className="ops-directory-table"
            columns={debtColumns}
            dataSource={[...ipoDebts.filter((item) => item.status !== "PAID"), ...loans.filter((item) => !["REPAID", "REJECTED"].includes(item.status))]}
            loading={loading}
            scroll={{ x: 900 }}
            pagination={{ pageSize: 10 }}
            locale={{ emptyText: <OpsEmpty description={loading ? "正在加载未结事项" : "当前没有未结资金事项。"} /> }}
          />
        </Card>
      </Space>
      <OpsModal
        title={`${adjustment?.direction === "credit" ? "创建上分订单" : "账户下分"} · ${adjustment?.accountNumber || ""}`}
        open={Boolean(adjustment)}
        onCancel={() => {
          if (submitting) return;
          setAdjustment(null);
          form.resetFields();
        }}
        onOk={() => form.submit()}
        confirmLoading={submitting}
        okText={adjustment?.direction === "credit" ? "确认创建并上分" : "确认下分"}
      >
        <Form form={form} layout="vertical" onFinish={submitAdjustment}>
          <Form.Item name="amount" label="调整金额" rules={[{ required: true, message: "请输入金额" }]}>
            <InputNumber min={0.01} precision={2} style={{ width: "100%" }} prefix="₹" />
          </Form.Item>
          <Form.Item
            name="referenceId"
            label="付款流水号"
            rules={[{ required: true, message: "请输入唯一流水号" }, { min: 8, message: "流水号至少 8 个字符" }]}
          >
            <Input placeholder="银行流水或内部工单号" />
          </Form.Item>
          <Form.Item name="note" label="调整说明" rules={[{ required: true, message: "请输入调整原因" }]}>
            <Input.TextArea rows={3} placeholder="说明资金来源或扣款原因" />
          </Form.Item>
        </Form>
      </OpsModal>
    </AdminShell>
  );
}
