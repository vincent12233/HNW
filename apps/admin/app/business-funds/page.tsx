"use client";

import { BankOutlined, CreditCardOutlined, ReloadOutlined, SearchOutlined, WalletOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Col, Form, Input, InputNumber, Modal, Row, Space, Statistic, Table, Tabs, Tag, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { isAxiosError } from "axios";
import { useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, formatCreditSuccessMessage, getApiErrorMessage } from '@/lib/api';
import { getBackendRole } from "@/lib/backend-role";

const { Title, Paragraph, Text } = Typography;

type DepositRecord = {
  id: string;
  amount: string | number;
  status: string;
  referenceId?: string | null;
  note?: string | null;
  createdAt: string;
  account: { accountNumber: string; user: { customerNo?: string | null; fullName: string; phone?: string | null } };
};

type WithdrawalRecord = {
  id: string;
  orderNo?: string | null;
  amount: string | number;
  status: string;
  createdAt: string;
  account: { accountNumber: string; user: { customerNo?: string | null; fullName: string; phone?: string | null } };
};

type LoanRecord = {
  id: string;
  orderNo: string;
  requestedAmount: string | number;
  approvedAmount?: string | number | null;
  outstandingAmount: string | number;
  interestRate: string | number;
  status: string;
  dueDate?: string | null;
  note?: string | null;
  createdAt: string;
  account: { accountNumber: string; user: { customerNo?: string | null; fullName: string; phone?: string | null } };
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

function customerLine(record: DepositRecord | WithdrawalRecord | LoanRecord) {
  return (
    <Space orientation="vertical" size={0}>
      <Text strong>{record.account.user.fullName || "未命名客户"}</Text>
      <Text type="secondary">{record.account.user.customerNo || "-"} / +91 {record.account.user.phone || "-"}</Text>
    </Space>
  );
}

export default function BusinessFundsPage() {
  const [deposits, setDeposits] = useState<DepositRecord[]>([]);
  const [withdrawals, setWithdrawals] = useState<WithdrawalRecord[]>([]);
  const [loans, setLoans] = useState<LoanRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const dedicatedOperator = getBackendRole() === "SUPPORT";
  const [adjustment, setAdjustment] = useState<{ accountNumber: string; direction: "credit" | "debit" } | null>(null);
  const [adjustmentSubmitting, setAdjustmentSubmitting] = useState(false);
  const adjustmentLock = useRef(false);
  const [adjustmentError, setAdjustmentError] = useState("");
  const [adjustmentForm] = Form.useForm();

  async function loadRecords() {
    setLoading(true);
    setError("");
    try {
      const [depositResponse, withdrawalResponse, loanResponse] = await Promise.all([
        api.get<DepositRecord[]>("/business/my-deposits"),
        api.get<WithdrawalRecord[]>("/business/my-withdrawals"),
        dedicatedOperator ? Promise.resolve({ data: [] as LoanRecord[] }) : api.get<LoanRecord[]>("/loans"),
      ]);
      setDeposits(Array.isArray(depositResponse.data) ? depositResponse.data : []);
      setWithdrawals(Array.isArray(withdrawalResponse.data) ? withdrawalResponse.data : []);
      setLoans(Array.isArray(loanResponse.data) ? loanResponse.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "资金记录加载失败");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadRecords();
  }, []);

  const filteredDeposits = useMemo(() => {
    const value = keyword.trim().toLowerCase();
    if (!value) return deposits;
    return deposits.filter((item) => [item.account.user.customerNo, item.account.user.fullName, item.account.user.phone, item.account.accountNumber, item.referenceId, item.status].some((field) => String(field ?? "").toLowerCase().includes(value)));
  }, [deposits, keyword]);

  const filteredWithdrawals = useMemo(() => {
    const value = keyword.trim().toLowerCase();
    if (!value) return withdrawals;
    return withdrawals.filter((item) => [item.orderNo, item.account.user.customerNo, item.account.user.fullName, item.account.user.phone, item.account.accountNumber, item.status].some((field) => String(field ?? "").toLowerCase().includes(value)));
  }, [withdrawals, keyword]);

  const totalDeposit = deposits.reduce((sum, item) => sum + Number(item.amount ?? 0), 0);
  const totalWithdrawal = withdrawals.reduce((sum, item) => sum + Number(item.amount ?? 0), 0);
  const pendingWithdrawal = withdrawals.filter((item) => item.status === "PENDING").length;
  const outstandingLoan = loans.reduce((sum, item) => sum + Number(item.outstandingAmount ?? 0), 0);

  async function submitAdjustment(values: { amount: number; referenceId: string; note: string }) {
    if (!adjustment || adjustmentLock.current) return;
    if (!Number.isFinite(values.amount) || values.amount <= 0) {
      message.error("请输入大于零的有效金额");
      return;
    }
    adjustmentLock.current = true;
    setAdjustmentError("");
    setAdjustmentSubmitting(true);
    try {
      const { data } = await api.post(
        `/admin/accounts/${encodeURIComponent(adjustment.accountNumber)}/${adjustment.direction}`,
        values,
      );
      message.success(
        adjustment.direction === "credit"
          ? formatCreditSuccessMessage(data, "专用运营上分已执行")
          : "专用运营扣款已执行",
      );
      setAdjustment(null); adjustmentForm.resetFields(); await loadRecords();
    } catch (requestError: unknown) {
      const response = isAxiosError<{ message?: string | string[] }>(requestError) ? requestError.response : undefined;
      const uncertain = !response || response.status >= 500;
      const text = uncertain
        ? "资金调整结果未确认，请先核对账户资金流水；保留原流水号，不要更换流水号重复提交。"
        : getApiErrorMessage(requestError, "资金调整未完成，请检查输入和权限");
      setAdjustmentError(text);
      message.error(text);
    } finally { adjustmentLock.current = false; setAdjustmentSubmitting(false); }
  }


  const depositColumns: ColumnsType<DepositRecord> = [
    { title: "客户", key: "customer", width: 240, render: (_, record) => customerLine(record) },
    { title: "交易账号", key: "accountNumber", width: 170, render: (_, record) => record.account.accountNumber },
    { title: "充值金额", dataIndex: "amount", width: 150, align: "right", render: formatMoney },
    { title: "状态", dataIndex: "status", width: 120, render: (value) => <Tag color="green">{value === "COMPLETED" ? "已完成" : value}</Tag> },
    { title: "流水号", dataIndex: "referenceId", width: 180, render: (value) => value || "-" },
    { title: "时间", dataIndex: "createdAt", width: 180, render: formatDate },
    ...(dedicatedOperator ? [{ title: "操作", width: 190, render: (_: unknown, record: DepositRecord) => <Space><Button size="small" type="primary" onClick={() => setAdjustment({ accountNumber: record.account.accountNumber, direction: "credit" })}>直接上分</Button><Button size="small" danger onClick={() => setAdjustment({ accountNumber: record.account.accountNumber, direction: "debit" })}>直接下分</Button></Space> }] : []),
  ];

  const withdrawalColumns: ColumnsType<WithdrawalRecord> = [
    { title: "订单号", dataIndex: "orderNo", width: 180, render: (value) => <Text copyable>{value || "-"}</Text> },
    { title: "客户", key: "customer", width: 240, render: (_, record) => customerLine(record) },
    { title: "交易账号", key: "accountNumber", width: 170, render: (_, record) => record.account.accountNumber },
    { title: "提现金额", dataIndex: "amount", width: 150, align: "right", render: formatMoney },
    { title: "状态", dataIndex: "status", width: 130, render: (value) => <Tag color={value === "PENDING" ? "orange" : value === "APPROVED" ? "green" : "red"}>{value === "PENDING" ? "待财务审核" : value === "APPROVED" ? "已通过" : value === "REJECTED" ? "已拒绝" : value}</Tag> },
    { title: "申请时间", dataIndex: "createdAt", width: 180, render: formatDate },
  ];

  const loanColumns: ColumnsType<LoanRecord> = [
    { title: "订单号", dataIndex: "orderNo", width: 180, render: (value) => <Text copyable>{value}</Text> },
    { title: "客户", key: "customer", width: 240, render: (_, record) => customerLine(record) },
    { title: "申请金额", dataIndex: "requestedAmount", width: 140, align: "right", render: (value) => Number(value) > 0 ? formatMoney(value) : "由财务决定" },
    { title: "批准金额", dataIndex: "approvedAmount", width: 140, align: "right", render: formatMoney },
    { title: "未还金额", dataIndex: "outstandingAmount", width: 140, align: "right", render: (value) => <Text type={Number(value) > 0 ? "danger" : undefined}>{formatMoney(value)}</Text> },
    { title: "状态", dataIndex: "status", width: 130, render: (value) => <Tag color={value === "PENDING" ? "orange" : value === "REPAID" ? "green" : value === "OVERDUE" ? "red" : "blue"}>{value}</Tag> },
    { title: "到期日", dataIndex: "dueDate", width: 150, render: (value) => value ? new Date(value).toLocaleDateString("zh-CN") : "-" },
    { title: "备注", dataIndex: "note", render: (value) => value || "-" },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>资金管理</Title>
          <Paragraph type="secondary">{dedicatedOperator ? "仅管理固定邀请码客户。确认实际到账或扣款依据后，可直接调整客户资金并写入审计流水。" : "集中查看自己名下客户的充值、提现和贷款记录。充值由财务上分，提现由财务审核。"}</Paragraph>
        </div>
        {error && <Alert type="error" title={error} showIcon />}
        <Row gutter={[16, 16]}>
          <Col xs={24} md={8}><Card><Statistic title="累计充值" value={totalDeposit} prefix={<WalletOutlined />} formatter={(value) => formatMoney(value as number)} /></Card></Col>
          <Col xs={24} md={8}><Card><Statistic title="累计提现申请" value={totalWithdrawal} prefix={<BankOutlined />} formatter={(value) => formatMoney(value as number)} /></Card></Col>
          <Col xs={24} md={8}><Card><Statistic title="待处理提现" value={pendingWithdrawal} prefix={<CreditCardOutlined />} suffix="笔" /></Card></Col>
          {!dedicatedOperator && <Col xs={24} md={8}><Card><Statistic title="客户贷款未还" value={outstandingLoan} formatter={(value) => formatMoney(value as number)} /></Card></Col>}
        </Row>
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input allowClear prefix={<SearchOutlined />} placeholder="搜索客户编号、手机号、交易账号、订单号或流水号" value={keyword} onChange={(event) => setKeyword(event.target.value)} style={{ width: 460 }} />
            <Text type="secondary"><ReloadOutlined onClick={loadRecords} /> 刷新</Text>
          </Space>
          <Tabs
            items={[
              { key: "deposits", label: "客户充值", children: <Table<DepositRecord> rowKey="id" columns={depositColumns} dataSource={filteredDeposits} loading={loading} scroll={{ x: 1120 }} pagination={{ pageSize: 12 }} /> },
              { key: "withdrawals", label: "客户提现", children: <Table<WithdrawalRecord> rowKey="id" columns={withdrawalColumns} dataSource={filteredWithdrawals} loading={loading} scroll={{ x: 1120 }} pagination={{ pageSize: 12 }} /> },
              ...(!dedicatedOperator ? [{ key: "loans", label: "客户贷款", children: <Table<LoanRecord> rowKey="id" columns={loanColumns} dataSource={loans} loading={loading} scroll={{ x: 1280 }} pagination={{ pageSize: 12 }} /> }] : []),
            ]}
          />
        </Card>
      </Space>
      <Modal title={`${adjustment?.direction === "credit" ? "直接上分" : "直接下分"} · ${adjustment?.accountNumber || ""}`} open={Boolean(adjustment)} onCancel={() => { if (adjustmentLock.current) return; setAdjustment(null); adjustmentForm.resetFields(); }} onOk={() => { if (!adjustmentLock.current) adjustmentForm.submit(); }} confirmLoading={adjustmentSubmitting} closable={!adjustmentSubmitting} maskClosable={!adjustmentSubmitting} keyboard={!adjustmentSubmitting} cancelButtonProps={{ disabled: adjustmentSubmitting }} okText="确认执行" destroyOnHidden>
        <Alert type="warning" showIcon title="请先核对外部付款或扣款依据，执行后会立即更新客户可用余额。" style={{ marginBottom: 16 }} />
        {adjustmentError && <Alert type="error" showIcon title={adjustmentError} style={{ marginBottom: 16 }} />}
        <Form form={adjustmentForm} disabled={adjustmentSubmitting} layout="vertical" onFinish={submitAdjustment}>
          <Form.Item name="amount" label="调整金额" rules={[{ required: true, message: "请输入金额" }]}><InputNumber min={0.01} precision={2} style={{ width: "100%" }} prefix="₹" /></Form.Item>
          <Form.Item name="referenceId" label="外部流水号" rules={[{ required: true, min: 6, message: "请输入唯一流水号" }]}><Input placeholder="银行流水或内部工单号" /></Form.Item>
          <Form.Item name="note" label="调整说明" rules={[{ required: true, min: 3, message: "请输入调整原因" }]}><Input.TextArea rows={3} maxLength={300} /></Form.Item>
        </Form>
      </Modal>
    </AdminShell>
  );
}
