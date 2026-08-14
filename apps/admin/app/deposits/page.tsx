"use client";

import { CheckOutlined, CloseOutlined, ReloadOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Modal, Space, Table, Tag, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;
type Deposit = {
  id: string; amount: string | number; paymentMethod?: string | null;
  referenceId?: string | null; note?: string | null; status: string; createdAt: string;
  account: { accountNumber: string; user: { fullName: string; customerNo?: string | null; phone?: string | null } };
};
const money = (value: string | number) => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(Number(value));

export default function DepositsPage() {
  const [rows, setRows] = useState<Deposit[]>([]);
  const [loading, setLoading] = useState(false);
  const [keyword, setKeyword] = useState("");
  const [rejecting, setRejecting] = useState<Deposit | null>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [processingId, setProcessingId] = useState("");

  async function load() {
    setLoading(true);
    try {
      const response = await api.get<Deposit[]>("/deposit/pending");
      setRows(Array.isArray(response.data) ? response.data : []);
    } catch (error: any) {
      message.error(error.response?.data?.message || "待上分记录加载失败");
    } finally { setLoading(false); }
  }
  useEffect(() => { load(); }, []);
  const data = useMemo(() => {
    const query = keyword.trim().toLowerCase();
    if (!query) return rows;
    return rows.filter((row) => [row.account.user.fullName, row.account.user.customerNo, row.account.user.phone, row.account.accountNumber, row.referenceId, row.paymentMethod].some((v) => String(v ?? "").toLowerCase().includes(query)));
  }, [rows, keyword]);

  function approve(row: Deposit) {
    Modal.confirm({
      title: "确认资金已经实际到账？",
      content: <Space orientation="vertical" size={4} style={{ marginTop: 12 }}><Text>客户：{row.account.user.fullName}</Text><Text>金额：{money(row.amount)}</Text><Text>付款流水号：{row.referenceId || "-"}</Text><Text type="danger">请以财务收款渠道的实际到账记录为准。</Text></Space>,
      okText: "已核实到账并上分",
      cancelText: "尚未核实",
      onOk: () => performApproval(row),
    });
  }
  async function performApproval(row: Deposit) {
    setProcessingId(row.id);
    try {
      await api.patch(`/deposit/${row.id}/approve`);
      message.success("财务上分完成");
      await load();
    } catch (error: any) { message.error(error.response?.data?.message || "上分失败"); }
    finally { setProcessingId(""); }
  }
  async function reject() {
    if (!rejecting || rejectNote.trim().length < 3) return message.error("请输入至少3个字符的拒绝原因");
    setProcessingId(rejecting.id);
    try {
      await api.patch(`/deposit/${rejecting.id}/reject`, { note: rejectNote.trim() });
      message.success("已拒绝并通知客户");
      setRejecting(null); setRejectNote(""); await load();
    } catch (error: any) { message.error(error.response?.data?.message || "拒绝失败"); }
    finally { setProcessingId(""); }
  }

  const columns: ColumnsType<Deposit> = [
    { title: "客户", width: 220, render: (_, r) => <Space orientation="vertical" size={0}><Text strong>{r.account.user.fullName}</Text><Text type="secondary">{r.account.user.customerNo || "-"} / +91 {r.account.user.phone || "-"}</Text></Space> },
    { title: "交易账号", width: 170, render: (_, r) => r.account.accountNumber },
    { title: "到账金额", width: 150, align: "right", render: (_, r) => <Text strong>{money(r.amount)}</Text> },
    { title: "存款方式", width: 140, render: (_, r) => r.paymentMethod || "-" },
    { title: "付款流水号", width: 210, render: (_, r) => r.referenceId || "-" },
    { title: "状态", width: 100, render: () => <Tag color="orange">待财务上分</Tag> },
    { title: "客服备注", width: 240, render: (_, r) => r.note || "-" },
    { title: "操作", fixed: "right", width: 210, render: (_, r) => <Space><Button type="primary" icon={<CheckOutlined />} loading={processingId === r.id} onClick={() => approve(r)}>确认到账并上分</Button><Button danger icon={<CloseOutlined />} disabled={!!processingId} onClick={() => setRejecting(r)}>拒绝</Button></Space> },
  ];

  return <AdminShell>
    <Space orientation="vertical" size="large" style={{ width: "100%" }}>
      <div><Title level={2}>客户存款核对与上分</Title><Paragraph type="secondary">客服仅转交客户申报的存款信息。财务须自行核对收款账户、付款流水号和实际到账金额，确认后直接上分，无需二次审核。</Paragraph></div>
      <Alert type="warning" showIcon title="只有财务可以确认资金到账。未在收款渠道查到实际资金时，请勿上分。" />
      <Card><Space style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}><Input.Search allowClear value={keyword} onChange={(e) => setKeyword(e.target.value)} placeholder="搜索客户、账号或付款流水号" style={{ width: 420 }} /><Button icon={<ReloadOutlined />} loading={loading} onClick={load}>刷新</Button></Space><Table rowKey="id" columns={columns} dataSource={data} loading={loading} scroll={{ x: 1450 }} /></Card>
    </Space>
    <Modal title="拒绝上分" open={!!rejecting} onCancel={() => setRejecting(null)} onOk={reject} confirmLoading={!!processingId} okButtonProps={{ danger: true }} okText="确认拒绝"><Input.TextArea value={rejectNote} onChange={(e) => setRejectNote(e.target.value)} placeholder="填写拒绝原因，客户会收到通知" maxLength={300} /></Modal>
  </AdminShell>;
}
