"use client";

import { CheckOutlined, CloseOutlined, PlusOutlined, ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Form, Input, InputNumber, Modal, Select, Space, Table, Typography, message } from "antd";
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
import { api, formatCreditSuccessMessage, getApiErrorMessage } from "@/lib/api";
import { getBackendRole } from "@/lib/backend-role";
import { FUNDING_COPY } from "@/lib/ops-funding";
import { filterLoadedRows, maskOpsPhone } from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";

const { Text } = Typography;

type Deposit = {
  id: string; amount: string | number; paymentMethod?: string | null;
  referenceId?: string | null; note?: string | null; status: string; createdAt: string;
  account: { accountNumber: string; user: { fullName: string; customerNo?: string | null; phone?: string | null } };
};

type StatusFilter = "PENDING" | "APPROVED" | "REJECTED" | "ALL";

function statusTag(status: string, dedicatedOperator: boolean) {
  if (status === "PENDING") {
    return <OpsStatusTag code={status} label={dedicatedOperator ? "待运营审核" : "待财务上分"} />;
  }
  return <OpsStatusTag code={status} />;
}

export default function DepositsPage() {
  const dedicatedOperator = getBackendRole() === "SUPPORT";
  const [rows, setRows] = useState<Deposit[]>([]);
  const [loading, setLoading] = useState(false);
  const [keyword, setKeyword] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("PENDING");
  const [rejecting, setRejecting] = useState<Deposit | null>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [processingId, setProcessingId] = useState("");
  const processing = useRef(false);
  const [loadError, setLoadError] = useState("");
  const canCreateTopUp = getBackendRole() === "FINANCE";
  const [createOpen, setCreateOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const creatingRef = useRef(false);
  const [createForm] = Form.useForm<{ accountNumber: string; amount: number; referenceId: string; note: string }>();

  const load = useCallback(async () => {
    setLoading(true);
    setLoadError("");
    try {
      const response =
        statusFilter === "PENDING"
          ? await api.get<Deposit[]>("/deposit/pending")
          : await api.get<Deposit[]>("/deposit/history", {
              params: { status: statusFilter },
            });
      setRows(Array.isArray(response.data) ? response.data : []);
    } catch (_error: unknown) {
      setLoadError("入金记录刷新失败，列表可能不是最新状态，请刷新后再审核。");
    } finally { setLoading(false); }
  }, [statusFilter]);
  useEffect(() => { void load(); }, [load]);
  const data = useMemo(
    () =>
      filterLoadedRows(rows, keyword, (row) => [
        row.account.user.fullName,
        row.account.user.customerNo,
        maskOpsPhone(row.account.user.phone, ""),
        row.account.accountNumber,
        row.referenceId,
        row.paymentMethod,
        row.status,
      ]),
    [rows, keyword],
  );

  function approve(row: Deposit) {
    if (processing.current || loading || loadError) return;
    Modal.confirm({
      title: "确认资金已经实际到账？",
      content: <Space orientation="vertical" size={4} style={{ marginTop: 12 }}><Text>客户：{row.account.user.fullName}</Text><Text>金额：<OpsMoney value={row.amount} /></Text><Text>付款流水号：{row.referenceId || "—"}</Text><Text type="danger">请以财务收款渠道的实际到账记录为准。未核实前状态保持待审核。</Text></Space>,
      okText: "已核实到账并上分",
      cancelText: "尚未核实",
      onOk: () => performApproval(row),
    });
  }
  async function performApproval(row: Deposit) {
    if (processing.current) return;
    processing.current = true;
    setProcessingId(row.id);
    try {
      const { data } = await api.patch(`/deposit/${row.id}/approve`);
      message.success(
        formatCreditSuccessMessage(
          data,
          dedicatedOperator ? "专用运营入金审核完成" : "财务上分完成",
        ),
      );
      await load();
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, "上分失败"));
    }
    finally { processing.current = false; setProcessingId(""); }
  }
  async function reject() {
    if (processing.current || loading || loadError) return;
    if (!rejecting || rejectNote.trim().length < 3) return message.error("请输入至少3个字符的拒绝原因");
    processing.current = true;
    setProcessingId(rejecting.id);
    try {
      await api.patch(`/deposit/${rejecting.id}/reject`, { note: rejectNote.trim() });
      message.success("已拒绝并通知客户");
      setRejecting(null); setRejectNote(""); await load();
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, "拒绝失败"));
    }
    finally { processing.current = false; setProcessingId(""); }
  }


  async function createTopUp(values: { accountNumber: string; amount: number; referenceId: string; note: string }) {
    if (creatingRef.current) return;
    creatingRef.current = true;
    setCreating(true);
    try {
      const accountNumber = values.accountNumber.trim().toUpperCase();
      const { data } = await api.post(`/admin/accounts/${accountNumber}/credit`, {
        amount: Number(values.amount).toFixed(2),
        referenceId: values.referenceId.trim(),
        note: values.note.trim(),
      });
      message.success(formatCreditSuccessMessage(data, "上分订单已创建并入账"));
      setCreateOpen(false);
      createForm.resetFields();
      await load();
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, "创建上分订单失败"));
    } finally {
      creatingRef.current = false;
      setCreating(false);
    }
  }

  const showActions = statusFilter === "PENDING";

  const columns: ColumnsType<Deposit> = [
    { title: "客户", width: 220, render: (_, r) => <Space orientation="vertical" size={0}><span className="ops-wrap-text">{r.account.user.fullName}</span><Text type="secondary">{r.account.user.customerNo || "—"} · {maskOpsPhone(r.account.user.phone)}</Text></Space> },
    { title: "交易账号", width: 170, render: (_, r) => <span className="ops-id">{r.account.accountNumber}</span> },
    { title: "到账金额", width: 150, align: "right", render: (_, r) => <OpsMoney value={r.amount} /> },
    { title: "存款方式", width: 140, render: (_, r) => r.paymentMethod || "-" },
    { title: "付款流水号", width: 210, render: (_, r) => r.referenceId || "-" },
    { title: "状态", width: 120, render: (_, r) => statusTag(r.status, dedicatedOperator) },
    { title: "客服备注", width: 240, render: (_, r) => <span className="ops-wrap-text">{r.note || "—"}</span> },
    { title: "申请时间", width: 180, render: (_, r) => formatOpsDateTime(r.createdAt) },
    ...(showActions
      ? [{
          title: "操作",
          fixed: "right" as const,
          width: 210,
          render: (_: unknown, r: Deposit) => (
            <Space>
              <Button type="primary" icon={<CheckOutlined />} disabled={!!processingId || loading || !!loadError} loading={processingId === r.id} onClick={() => approve(r)}>确认到账并上分</Button>
              <Button danger icon={<CloseOutlined />} disabled={!!processingId || loading || !!loadError} onClick={() => { setRejectNote(""); setRejecting(r); }}>拒绝</Button>
            </Space>
          ),
        }]
      : []),
  ];

  return <AdminShell>
    <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
      {loadError ? <OpsErrorState title={loadError} onRetry={load} /> : null}
      <OpsPageHeader
        title={FUNDING_COPY.depositsTitle}
        crumbs={[{ title: "资金" }, { title: FUNDING_COPY.depositsTitle }]}
        description={dedicatedOperator
          ? "仅显示归属当前专用运营员、使用固定邀请码注册的客户。请核对付款流水和实际到账金额后处理。可通过状态筛选查看历史；待审列表仍使用原有审核接口。"
          : "客户完成存款后，财务在此单人创建上分订单：填写交易账号、到账金额与付款流水号，确认后立即入账。无需双人复核。固定邀请码客户不会出现在待审列表。"}
      />
      <Alert type="warning" showIcon title={dedicatedOperator ? "只有当前专用运营员可以处理本页显示的客户。未在收款渠道查到实际资金时，请勿上分。" : "客户存款完成后由财务创建上分订单。未在收款渠道查到实际资金时，请勿上分。也可在「上下分」中对账户执行上分或下分。"} description={`${FUNDING_COPY.noGateway} ${FUNDING_COPY.noVipPriority} ${FUNDING_COPY.noDualApproval}`} />
      <OpsToolbar
        extra={
          <Space wrap>
            {canCreateTopUp && (
              <Button type="primary" icon={<PlusOutlined />} onClick={() => { createForm.resetFields(); setCreateOpen(true); }} aria-label="创建上分订单">
                创建上分订单
              </Button>
            )}
            <Button icon={<ReloadOutlined />} loading={loading} onClick={load} aria-label="刷新上分订单">刷新</Button>
          </Space>
        }
      >
        <Input allowClear prefix={<SearchOutlined aria-hidden />} value={keyword} onChange={(e) => setKeyword(e.target.value)} placeholder="搜索已加载的客户、账号或付款流水号" aria-label="搜索已加载的入金记录" style={{ width: 360, maxWidth: "100%" }} />
        <Select
          value={statusFilter}
          style={{ width: 160 }}
          aria-label="按入金状态筛选"
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
      <Table
        rowKey="id"
        className="ops-directory-table"
        columns={columns}
        dataSource={data}
        loading={loading}
        scroll={{ x: showActions ? 1600 : 1400 }}
        pagination={OPS_TABLE_PAGINATION}
        locale={{ emptyText: <OpsEmpty description={loading ? "正在加载上分订单" : "当前没有上分订单。"} onRetry={loading ? undefined : load} /> }}
      />
    </Space>
    <OpsModal title="拒绝上分" open={!!rejecting} onCancel={() => { if (!processing.current) setRejecting(null); }} onOk={reject} confirmLoading={!!processingId} okButtonProps={{ danger: true }} okText="确认拒绝" zIndex={2100}><Input.TextArea disabled={!!processingId} value={rejectNote} onChange={(e) => setRejectNote(e.target.value)} placeholder="填写拒绝原因，客户会收到通知" maxLength={300} /></OpsModal>
    <OpsModal
      title="创建上分订单"
      open={createOpen}
      onCancel={() => { if (!creating) setCreateOpen(false); }}
      onOk={() => createForm.submit()}
      confirmLoading={creating}
      okText="确认创建并上分"
      destroyOnHidden
      zIndex={2100}
    >
      <Alert type="info" showIcon style={{ marginBottom: 16 }} title="请先确认客户已实际到账，再填写交易账号与付款流水号。提交后立即入账，无需双人复核。" />
      <Form form={createForm} layout="vertical" onFinish={createTopUp}>
        <Form.Item name="accountNumber" label="交易账号" rules={[{ required: true, message: "请输入交易账号" }]}>
          <Input placeholder="例如 ACC10001" />
        </Form.Item>
        <Form.Item name="amount" label="上分金额" rules={[{ required: true, message: "请输入上分金额" }]}>
          <InputNumber min={0.01} precision={2} style={{ width: "100%" }} prefix="₹" />
        </Form.Item>
        <Form.Item name="referenceId" label="付款流水号" rules={[{ required: true, message: "请输入付款流水号" }, { min: 8, message: "流水号至少 8 个字符" }]}>
          <Input placeholder="银行流水或支付参考号" />
        </Form.Item>
        <Form.Item name="note" label="备注" rules={[{ required: true, message: "请填写上分说明" }]}>
          <Input.TextArea rows={3} placeholder="例如：客户 UPI 到账已核实" maxLength={500} />
        </Form.Item>
      </Form>
    </OpsModal>
  </AdminShell>;
}
