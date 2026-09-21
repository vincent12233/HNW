"use client";

import { BankOutlined, CreditCardOutlined, ReloadOutlined, SearchOutlined, WalletOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Col, Form, Input, InputNumber, Row, Space, Statistic, Table, Tabs, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { isAxiosError } from "axios";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, formatCreditSuccessMessage, getApiErrorMessage } from "@/lib/api";
import { getBackendRole } from "@/lib/backend-role";
import { filterLoadedRows, maskOpsPhone } from "@/lib/ops-directory";
import { formatInr, formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { FUNDING_COPY } from "@/lib/ops-funding";

const { Text } = Typography;

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

function customerLine(record: DepositRecord | WithdrawalRecord | LoanRecord) {
  return (
    <Space orientation="vertical" size={0}>
      <span className="ops-wrap-text">{record.account.user.fullName || "未命名客户"}</span>
      <Text type="secondary">{record.account.user.customerNo || "—"} · {maskOpsPhone(record.account.user.phone)}</Text>
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

  const loadRecords = useCallback(async () => {
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
  }, [dedicatedOperator]);

  useEffect(() => {
    void loadRecords();
  }, [loadRecords]);

  const filteredDeposits = useMemo(
    () =>
      filterLoadedRows(deposits, keyword, (item) => [
        item.account.user.customerNo,
        item.account.user.fullName,
        maskOpsPhone(item.account.user.phone, ""),
        item.account.accountNumber,
        item.referenceId,
        item.status,
      ]),
    [deposits, keyword],
  );

  const filteredWithdrawals = useMemo(
    () =>
      filterLoadedRows(withdrawals, keyword, (item) => [
        item.orderNo,
        item.account.user.customerNo,
        item.account.user.fullName,
        maskOpsPhone(item.account.user.phone, ""),
        item.account.accountNumber,
        item.status,
      ]),
    [withdrawals, keyword],
  );

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
      setAdjustment(null);
      adjustmentForm.resetFields();
      await loadRecords();
    } catch (requestError: unknown) {
      const response = isAxiosError<{ message?: string | string[] }>(requestError) ? requestError.response : undefined;
      const uncertain = !response || response.status >= 500;
      const text = uncertain
        ? "资金调整结果未确认，请先核对账户资金流水；保留原流水号，不要更换流水号重复提交。"
        : getApiErrorMessage(requestError, "资金调整未完成，请检查输入和权限");
      setAdjustmentError(text);
      message.error(text);
    } finally {
      adjustmentLock.current = false;
      setAdjustmentSubmitting(false);
    }
  }

  const depositColumns: ColumnsType<DepositRecord> = [
    { title: "客户", key: "customer", width: 240, render: (_, record) => customerLine(record) },
    { title: "交易账号", key: "accountNumber", width: 170, render: (_, record) => <span className="ops-id">{record.account.accountNumber}</span> },
    { title: "充值金额", dataIndex: "amount", width: 150, align: "right", render: (value) => <OpsMoney value={value} /> },
    { title: "状态", dataIndex: "status", width: 120, render: (value: string) => <OpsStatusTag code={value} /> },
    { title: "流水号", dataIndex: "referenceId", width: 180, render: (value) => <span className="ops-wrap-text">{value || "—"}</span> },
    { title: "时间", dataIndex: "createdAt", width: 180, render: (value: string) => formatOpsDateTime(value) },
    ...(dedicatedOperator
      ? [{
          title: "操作",
          width: 190,
          render: (_: unknown, record: DepositRecord) => (
            <Space>
              <Button size="small" type="primary" aria-label={`直接上分 ${record.account.accountNumber}`} onClick={() => setAdjustment({ accountNumber: record.account.accountNumber, direction: "credit" })}>直接上分</Button>
              <Button size="small" danger aria-label={`直接下分 ${record.account.accountNumber}`} onClick={() => setAdjustment({ accountNumber: record.account.accountNumber, direction: "debit" })}>直接下分</Button>
            </Space>
          ),
        }]
      : []),
  ];

  const withdrawalColumns: ColumnsType<WithdrawalRecord> = [
    { title: "订单号", dataIndex: "orderNo", width: 180, render: (value) => <Text copyable={{ text: value || "" }}>{value || "—"}</Text> },
    { title: "客户", key: "customer", width: 240, render: (_, record) => customerLine(record) },
    { title: "交易账号", key: "accountNumber", width: 170, render: (_, record) => <span className="ops-id">{record.account.accountNumber}</span> },
    { title: "提现金额", dataIndex: "amount", width: 150, align: "right", render: (value) => <OpsMoney value={value} /> },
    {
      title: "状态",
      dataIndex: "status",
      width: 130,
      render: (value: string) => <OpsStatusTag code={value} label={value === "PENDING" ? "待财务审核" : undefined} />,
    },
    { title: "申请时间", dataIndex: "createdAt", width: 180, render: (value: string) => formatOpsDateTime(value) },
  ];

  const loanColumns: ColumnsType<LoanRecord> = [
    { title: "订单号", dataIndex: "orderNo", width: 180, render: (value) => <Text copyable>{value}</Text> },
    { title: "客户", key: "customer", width: 240, render: (_, record) => customerLine(record) },
    { title: "申请金额", dataIndex: "requestedAmount", width: 140, align: "right", render: (value) => Number(value) > 0 ? <OpsMoney value={value} /> : "由财务决定" },
    { title: "批准金额", dataIndex: "approvedAmount", width: 140, align: "right", render: (value) => <OpsMoney value={value} /> },
    { title: "未还金额", dataIndex: "outstandingAmount", width: 140, align: "right", render: (value) => <Text type={Number(value) > 0 ? "danger" : undefined}><OpsMoney value={value} /></Text> },
    { title: "状态", dataIndex: "status", width: 130, render: (value: string) => <OpsStatusTag code={value} /> },
    { title: "到期日", dataIndex: "dueDate", width: 150, render: (value) => value ? formatOpsDateTime(value) : "—" },
    { title: "备注", dataIndex: "note", render: (value) => <span className="ops-wrap-text">{value || "—"}</span> },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title="资金管理"
          crumbs={[{ title: "资金" }, { title: "资金管理" }]}
          description={dedicatedOperator
            ? `仅管理固定邀请码客户。确认实际到账或扣款依据后，可直接调整客户资金并写入审计流水。${FUNDING_COPY.noGateway} ${FUNDING_COPY.noVipPriority}`
            : `集中查看自己名下客户的充值、提现和贷款记录。充值由财务上分，提现由财务审核。${FUNDING_COPY.noVipPriority}`}
        />
        {error ? <OpsErrorState title={error} onRetry={loadRecords} /> : null}
        <Row gutter={[16, 16]}>
          <Col xs={24} md={8}><Card><Statistic title="累计充值" value={totalDeposit} prefix={<WalletOutlined aria-hidden />} formatter={() => formatInr(totalDeposit)} /></Card></Col>
          <Col xs={24} md={8}><Card><Statistic title="累计提现申请" value={totalWithdrawal} prefix={<BankOutlined aria-hidden />} formatter={() => formatInr(totalWithdrawal)} /></Card></Col>
          <Col xs={24} md={8}><Card><Statistic title="待处理提现" value={pendingWithdrawal} prefix={<CreditCardOutlined aria-hidden />} suffix="笔" /></Card></Col>
          {!dedicatedOperator && <Col xs={24} md={8}><Card><Statistic title="客户贷款未还" value={outstandingLoan} formatter={() => formatInr(outstandingLoan)} /></Card></Col>}
        </Row>
        <OpsToolbar extra={<Button icon={<ReloadOutlined />} loading={loading} onClick={loadRecords} aria-label="刷新资金记录">刷新</Button>}>
          <Input allowClear prefix={<SearchOutlined aria-hidden />} placeholder="搜索已加载的客户编号、交易账号、订单号或流水号" value={keyword} onChange={(event) => setKeyword(event.target.value)} aria-label="搜索已加载的资金记录" style={{ width: 460, maxWidth: "100%" }} />
        </OpsToolbar>
        <Text type="secondary">{FUNDING_COPY.loadedFilter}</Text>
        <Tabs
          items={[
            {
              key: "deposits",
              label: "客户充值",
              children: (
                <Table<DepositRecord>
                  rowKey="id"
                  className="ops-directory-table"
                  columns={depositColumns}
                  dataSource={filteredDeposits}
                  loading={loading}
                  scroll={{ x: 1120 }}
                  pagination={OPS_TABLE_PAGINATION}
                  locale={{ emptyText: <OpsEmpty description="当前没有入金记录。" onRetry={loadRecords} /> }}
                />
              ),
            },
            {
              key: "withdrawals",
              label: "客户提现",
              children: (
                <Table<WithdrawalRecord>
                  rowKey="id"
                  className="ops-directory-table"
                  columns={withdrawalColumns}
                  dataSource={filteredWithdrawals}
                  loading={loading}
                  scroll={{ x: 1120 }}
                  pagination={OPS_TABLE_PAGINATION}
                  locale={{ emptyText: <OpsEmpty description="当前没有提现记录。" onRetry={loadRecords} /> }}
                />
              ),
            },
            ...(!dedicatedOperator
              ? [{
                  key: "loans",
                  label: "客户贷款",
                  children: (
                    <Table<LoanRecord>
                      rowKey="id"
                      className="ops-directory-table"
                      columns={loanColumns}
                      dataSource={loans}
                      loading={loading}
                      scroll={{ x: 1280 }}
                      pagination={OPS_TABLE_PAGINATION}
                      locale={{ emptyText: <OpsEmpty description="当前没有贷款记录。" onRetry={loadRecords} /> }}
                    />
                  ),
                }]
              : []),
          ]}
        />
      </Space>
      <OpsModal
        title={`${adjustment?.direction === "credit" ? "直接上分" : "直接下分"} · ${adjustment?.accountNumber || ""}`}
        open={Boolean(adjustment)}
        onCancel={() => { if (adjustmentLock.current) return; setAdjustment(null); adjustmentForm.resetFields(); }}
        onOk={() => { if (!adjustmentLock.current) adjustmentForm.submit(); }}
        confirmLoading={adjustmentSubmitting}
        closable={!adjustmentSubmitting}
        keyboard={!adjustmentSubmitting}
        cancelButtonProps={{ disabled: adjustmentSubmitting }}
        okText="提交到服务器"
        zIndex={2100}
        destroyOnHidden
      >
        <Alert type="warning" showIcon title="请先核对外部付款或扣款依据。结果只在服务器成功后刷新，未核实前不要提交。" style={{ marginBottom: 16 }} />
        {adjustmentError && <Alert type="error" showIcon title={adjustmentError} style={{ marginBottom: 16 }} />}
        <Form form={adjustmentForm} disabled={adjustmentSubmitting} layout="vertical" onFinish={submitAdjustment}>
          <Form.Item name="amount" label="调整金额" rules={[{ required: true, message: "请输入金额" }]}><InputNumber min={0.01} precision={2} style={{ width: "100%" }} prefix="₹" /></Form.Item>
          <Form.Item name="referenceId" label="外部流水号" rules={[{ required: true, min: 6, message: "请输入唯一流水号" }]}><Input placeholder="银行流水或内部工单号" /></Form.Item>
          <Form.Item name="note" label="调整说明" rules={[{ required: true, min: 3, message: "请输入调整原因" }]}><Input.TextArea rows={3} maxLength={300} /></Form.Item>
        </Form>
      </OpsModal>
    </AdminShell>
  );
}
