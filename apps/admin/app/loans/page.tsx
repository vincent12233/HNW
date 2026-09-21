"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, DatePicker, Input, InputNumber, Modal, Space, Table, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useRef, useState } from "react";
import { isAxiosError } from "axios";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api } from "@/lib/api";
import { getBackendRole } from "@/lib/backend-role";
import { FUNDING_COPY } from "@/lib/ops-funding";
import { filterLoadedRows, maskOpsPhone } from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";

const { Text } = Typography;

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
  account: {
    accountNumber: string;
    user: { customerNo?: string | null; fullName: string; phone?: string | null; status: string };
  };
};

function statusTag(status: string) {
  const labels: Record<string, string> = {
    PENDING: "待审核",
    APPROVED: "已批准",
    DISBURSED: "已到账",
    PARTIAL_REPAID: "部分还款",
    REPAID: "已结清",
    OVERDUE: "已逾期",
  };
  return <OpsStatusTag code={status} label={labels[status]} />;
}

export default function LoansPage() {
  const canManage = getBackendRole() === 'FINANCE';
  const [creating, setCreating] = useState(false);

  function createLoan() {
    if (!canManage || creating) return;
    setCreating(true);
    let accountNumber = '';
    let amount: number | null = null;
    Modal.confirm({
      title: '财务创建贷款申请', okText: '创建', cancelText: '取消',
      afterClose: () => setCreating(false),
      content: <Space orientation="vertical" style={{ width: '100%' }}>
        <Input placeholder="客户交易账号" onChange={(e) => { accountNumber = e.target.value; }} />
        <InputNumber min={0.01} precision={2} placeholder="拟批准金额" onChange={(value) => { amount = value; }} />
      </Space>,
      async onOk() {
        if (!accountNumber.trim() || amount === null || !Number.isFinite(amount) || amount <= 0) {
          message.error('请输入交易账号和有效金额'); throw new Error('Invalid loan');
        }
        try {
          await api.post('/loans', {
            accountNumber: accountNumber.trim(),
            amount: Number(amount).toFixed(2),
          });
        } catch (error) {
          message.error('创建结果未确认，请先核对贷款记录'); throw error;
        }
        message.success('已创建，请审核通过并上分');
        await loadItems();
      },
    });
  }
  const [items, setItems] = useState<LoanRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const loadGeneration = useRef(0);

  async function loadItems() {
    const generation = ++loadGeneration.current;
    setLoading(true);
    setError("");
    try {
      const response = await api.get<LoanRecord[]>("/loans");
      if (!Array.isArray(response.data)) throw new Error("Invalid loan response");
      if (generation !== loadGeneration.current) return;
      setItems(response.data);
    } catch (requestError: unknown) {
      if (generation !== loadGeneration.current) return;
      const responseMessage = isAxiosError(requestError) ? requestError.response?.data?.message : undefined;
      setError(Array.isArray(responseMessage) ? responseMessage.join("，") : typeof responseMessage === "string" ? responseMessage : "贷款记录加载失败，请刷新重试");
    } finally {
      if (generation === loadGeneration.current) setLoading(false);
    }
  }

  async function approve(record: LoanRecord) {
    let amount = Number(record.requestedAmount) > 0 ? String(record.requestedAmount) : '';
    let dueDate = "";
    let note = "";
    Modal.confirm({
      title: "审核通过并自动到账",
      content: (
        <Space orientation="vertical" style={{ width: "100%" }}>
          <Text type="secondary">通过后资金会直接进入客户账户，还款只做后台登记，不从账户扣除。</Text>
          <InputNumber min={0.01} precision={2} style={{ width: "100%" }} defaultValue={amount ? Number(amount) : undefined} placeholder="财务决定批准金额" onChange={(value) => { amount = String(value ?? ""); }} />
          <DatePicker style={{ width: "100%" }} placeholder="到期日" disabledDate={(date) => date.startOf("day").valueOf() < Date.now() - 86400000} onChange={(date) => { dueDate = date?.format("YYYY-MM-DD") ?? ""; }} />
          <Input placeholder="备注" onChange={(event) => { note = event.target.value; }} />
        </Space>
      ),
      okText: "通过并到账",
      cancelText: "取消",
      async onOk() {
        if (!Number.isFinite(Number(amount)) || Number(amount) <= 0 || !dueDate) {
          message.error("请输入有效的批准金额和到期日");
          throw new Error("Invalid loan approval values");
        }
        await api.patch(`/loans/${record.id}/approve`, {
          approvedAmount: Number(amount).toFixed(2),
          dueDate: dueDate || undefined,
          note,
        });
        message.success("贷款已审核通过并自动到账");
        await loadItems();
      },
    });
  }

  async function repay(record: LoanRecord) {
    let amount = "";
    let note = "";
    Modal.confirm({
      title: "登记还款",
      content: (
        <Space orientation="vertical" style={{ width: "100%" }}>
          <Text type="secondary">这里只登记客户还款，不会从客户交易账户扣款。</Text>
          <InputNumber min={0.01} max={Number(record.outstandingAmount)} precision={2} style={{ width: "100%" }} placeholder="还款金额" onChange={(value) => { amount = String(value ?? ""); }} />
          <Input placeholder="备注" onChange={(event) => { note = event.target.value; }} />
        </Space>
      ),
      okText: "登记",
      cancelText: "取消",
      async onOk() {
        if (!Number.isFinite(Number(amount)) || Number(amount) <= 0 || Number(amount) > Number(record.outstandingAmount)) {
          message.error("还款金额必须大于零且不能超过未还金额");
          throw new Error("Invalid repayment amount");
        }
        await api.patch(`/loans/${record.id}/repay`, {
          amount: Number(amount).toFixed(2),
          note,
        });
        message.success("还款已登记");
        await loadItems();
      },
    });
  }

  useEffect(() => {
    loadItems();
    return () => { loadGeneration.current += 1; };
  }, []);

  const filtered = useMemo(
    () =>
      filterLoadedRows(items, keyword, (item) => [
        item.orderNo,
        item.account.accountNumber,
        item.account.user.customerNo,
        item.account.user.fullName,
        maskOpsPhone(item.account.user.phone, ""),
        item.status,
        item.note,
      ]),
    [items, keyword],
  );

  const columns: ColumnsType<LoanRecord> = [
    { title: "订单号", dataIndex: "orderNo", width: 180, fixed: "left", render: (value) => <Text copyable>{value}</Text> },
    { title: "客户", key: "customer", width: 250, render: (_, record) => <Space orientation="vertical" size={0}><span className="ops-wrap-text">{record.account.user.fullName}</span><Text type="secondary">{record.account.user.customerNo || "—"} · {maskOpsPhone(record.account.user.phone)}</Text></Space> },
    { title: "交易账号", key: "account", width: 160, render: (_, record) => <span className="ops-id">{record.account.accountNumber}</span> },
    { title: "申请金额", dataIndex: "requestedAmount", width: 140, align: "right", render: (value) => Number(value) > 0 ? <OpsMoney value={value} /> : "由财务决定" },
    { title: "批准金额", dataIndex: "approvedAmount", width: 140, align: "right", render: (value) => <OpsMoney value={value} /> },
    { title: "未还金额", dataIndex: "outstandingAmount", width: 140, align: "right", render: (value) => <Text type={Number(value) > 0 ? "danger" : undefined}><OpsMoney value={value} /></Text> },
    { title: "状态", dataIndex: "status", width: 120, render: statusTag },
    { title: "到期日", dataIndex: "dueDate", width: 150, render: (value) => value ? formatOpsDateTime(value) : "—" },
    { title: "备注", dataIndex: "note", width: 220, render: (value) => <span className="ops-wrap-text">{value || "—"}</span> },
    {
      title: "操作",
      key: "actions",
      width: 260,
      fixed: "right",
      render: (_, record) => (
        <Space>
          <Button size="small" type="primary" disabled={record.status !== "PENDING"} aria-label="通过贷款" onClick={() => approve(record)}>通过</Button>
          <Button size="small" danger disabled={record.status !== "PENDING"} aria-label="拒绝贷款" onClick={() => {
            Modal.confirm({
              title: "确认拒绝该贷款申请？",
              content: `${record.account.user.fullName} · 当前待审核。结果只在服务器成功后更新。`,
              okText: "提交到服务器",
              okButtonProps: { danger: true },
              cancelText: "返回",
              async onOk() {
                await api.patch(`/loans/${record.id}/reject`, { note: "后台拒绝" });
                message.success("贷款已拒绝");
                await loadItems();
              },
            });
          }}>拒绝</Button>
          <Button size="small" disabled={!["DISBURSED", "PARTIAL_REPAID", "OVERDUE"].includes(record.status)} onClick={() => repay(record)}>还款</Button>
          <Button size="small" disabled={!["DISBURSED", "PARTIAL_REPAID"].includes(record.status)} aria-label="标记贷款逾期" onClick={() => {
            Modal.confirm({
              title: "确认标记逾期？",
              content: "逾期只更新当前贷款状态，不新增审批层级。结果只在服务器成功后刷新。",
              okText: "提交到服务器",
              cancelText: "返回",
              async onOk() {
                await api.patch(`/loans/${record.id}/overdue`);
                message.success("已标记逾期");
                await loadItems();
              },
            });
          }}>逾期</Button>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={FUNDING_COPY.loansTitle}
          crumbs={[{ title: "资金" }, { title: FUNDING_COPY.loansTitle }]}
          description={`客户提交申请无需填写金额。财务决定批准金额，审核通过后自动上分。${FUNDING_COPY.noVipPriority}`}
        />
        {error ? <OpsErrorState title={error} onRetry={loadItems} /> : null}
        <OpsToolbar
          extra={
            <Space wrap>
              <Button icon={<ReloadOutlined />} onClick={loadItems} loading={loading} aria-label="刷新贷款列表">刷新</Button>
              {canManage && <Button type="primary" disabled={creating} onClick={createLoan} aria-label="创建贷款">创建贷款</Button>}
            </Space>
          }
        >
          <Input allowClear prefix={<SearchOutlined aria-hidden />} placeholder="搜索已加载的订单号、客户或交易账号" value={keyword} onChange={(event) => setKeyword(event.target.value)} aria-label="搜索已加载的贷款记录" style={{ width: 420, maxWidth: "100%" }} />
        </OpsToolbar>
        <Text type="secondary">{FUNDING_COPY.loadedFilter}</Text>
        <Table<LoanRecord> rowKey="id" className="ops-directory-table" columns={canManage ? columns : columns.filter((column) => column.key !== 'actions')} dataSource={filtered} loading={loading} locale={{ emptyText: <OpsEmpty description={error ? "贷款记录未能加载，请刷新重试" : "暂无贷款记录"} onRetry={loadItems} /> }} scroll={{ x: 1720 }} pagination={OPS_TABLE_PAGINATION} />
      </Space>
    </AdminShell>
  );
}
