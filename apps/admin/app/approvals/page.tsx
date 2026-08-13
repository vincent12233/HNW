"use client";
import { Button, Card, Input, Modal, Space, Table, Tag, Typography, message } from "antd";
import { useEffect, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

type Approval = { id: string; action: string; reason: string; status: string; payload: { accountNumber?: string; amount?: string; referenceId?: string }; requestedAt: string; requestedBy: { fullName: string; role: string } };
export default function ApprovalsPage() {
  const [rows, setRows] = useState<Approval[]>([]); const [loading, setLoading] = useState(false); const [note, setNote] = useState(""); const [selected, setSelected] = useState<Approval | null>(null);
  const load = async () => { setLoading(true); try { setRows((await api.get<Approval[]>("/admin/approvals", { params: { status: "PENDING" } })).data); } catch { message.error("复核任务加载失败"); } finally { setLoading(false); } };
  useEffect(() => { void load(); }, []);
  const decide = async (decision: "APPROVED" | "REJECTED") => { if (!selected) return; try { await api.post(`/admin/approvals/${selected.id}/decision`, { decision, note }); message.success(decision === "APPROVED" ? "已批准并执行" : "已拒绝"); setSelected(null); setNote(""); await load(); } catch (e: any) { message.error(e.response?.data?.message || "操作失败"); } };
  return <AdminShell><Space direction="vertical" size={18} style={{ width: "100%" }}><div><Typography.Title level={2} style={{ marginBottom: 4 }}>高风险操作双人复核</Typography.Title><Typography.Text type="secondary">申请人与批准人必须是不同员工，批准前资金不会发生变化。</Typography.Text></div><Card><Table rowKey="id" loading={loading} dataSource={rows} pagination={{ pageSize: 20 }} columns={[
    { title: "类型", dataIndex: "action", render: (v) => <Tag color={v.includes("CREDIT") ? "green" : "orange"}>{v.includes("CREDIT") ? "账户入金" : "账户扣款"}</Tag> },
    { title: "账户", render: (_, r) => r.payload.accountNumber || "-" }, { title: "金额", render: (_, r) => `₹${Number(r.payload.amount || 0).toLocaleString("en-IN", { minimumFractionDigits: 2 })}` },
    { title: "业务流水号", render: (_, r) => r.payload.referenceId || "-" }, { title: "发起人", render: (_, r) => r.requestedBy.fullName }, { title: "发起时间", dataIndex: "requestedAt", render: (v) => new Date(v).toLocaleString() },
    { title: "操作", render: (_, r) => <Button type="primary" onClick={() => setSelected(r)}>独立复核</Button> },
  ]} /></Card></Space><Modal title="独立复核确认" open={!!selected} onCancel={() => setSelected(null)} footer={<Space><Button danger onClick={() => decide("REJECTED")}>拒绝</Button><Button type="primary" onClick={() => decide("APPROVED")}>批准并执行</Button></Space>}><p>请核对账户、金额和业务流水号。发起人无法批准自己的申请。</p><Input.TextArea rows={3} value={note} onChange={(e) => setNote(e.target.value)} placeholder="复核备注（建议填写）" /></Modal></AdminShell>;
}
