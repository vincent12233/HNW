"use client";

import { CheckOutlined, CloseOutlined, ReloadOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Popconfirm, Space, Table, Tag, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;
type OtcOrder = {
  id: string; orderNo: string; quantity: number; price: string; amount: string;
  status: "PENDING" | "APPROVED" | "REJECTED"; createdAt: string;
  instrument: { symbol: string; name: string };
  account: { accountNumber: string; user: { fullName: string; phone?: string } };
};
const money = (value: string | number) => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(Number(value));

export default function BusinessOtcPage() {
  const [items, setItems] = useState<OtcOrder[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [reviewing, setReviewing] = useState<string | null>(null);

  async function load() {
    setLoading(true); setError("");
    try { const response = await api.get<OtcOrder[]>("/otc/orders/pending"); setItems(response.data ?? []); }
    catch { setError("OTC 待审核订单加载失败，请刷新重试。"); }
    finally { setLoading(false); }
  }
  useEffect(() => { void load(); }, []);

  async function review(id: string, decision: "approve" | "reject") {
    if (reviewing) return;
    setReviewing(id);
    try {
      await api.patch(`/otc/orders/${id}/${decision}`, decision === "reject" ? { note: "Rejected by backend review" } : {});
      message.success(decision === "approve" ? "审核通过，已完成结算并转入持仓" : "订单已拒绝");
      await load();
    } catch { message.error("审核未完成，请刷新订单状态后重试。"); }
    finally { setReviewing(null); }
  }

  const columns: ColumnsType<OtcOrder> = [
    { title: "订单编号", dataIndex: "orderNo", width: 210, render: (v) => <Text copyable>{v}</Text> },
    { title: "客户 / 账户", width: 190, render: (_, r) => <Space orientation="vertical" size={0}><Text strong>{r.account.user.fullName}</Text><Text type="secondary">{r.account.accountNumber}</Text></Space> },
    { title: "股票", width: 170, render: (_, r) => <Space orientation="vertical" size={0}><Text strong>{r.instrument.symbol}</Text><Text type="secondary">{r.instrument.name}</Text></Space> },
    { title: "数量", dataIndex: "quantity", align: "right", width: 100 },
    { title: "成交单价", dataIndex: "price", align: "right", width: 140, render: money },
    { title: "订单金额", dataIndex: "amount", align: "right", width: 150, render: money },
    { title: "状态", dataIndex: "status", width: 120, render: (v: OtcOrder['status']) => <Tag color={v === 'APPROVED' ? 'green' : v === 'REJECTED' ? 'red' : 'gold'}>{{PENDING:'待审核',APPROVED:'已通过',REJECTED:'已拒绝'}[v] ?? '未知状态'}</Tag> },
    { title: "操作", fixed: "right", width: 190, render: (_, r) => <Space>
      <Popconfirm title="确认通过此订单？" description="通过后将结算资金并转入客户持仓。" okText="确认通过" cancelText="取消" onConfirm={() => review(r.id, "approve")} disabled={!!reviewing}>
        <Button type="primary" size="small" icon={<CheckOutlined />} disabled={!!reviewing} loading={reviewing === r.id}>通过</Button>
      </Popconfirm>
      <Popconfirm title="确认拒绝此订单？" okText="确认拒绝" cancelText="取消" onConfirm={() => review(r.id, "reject")} disabled={!!reviewing}>
        <Button danger size="small" icon={<CloseOutlined />} disabled={!!reviewing}>拒绝</Button>
      </Popconfirm>
    </Space> },
  ];
  return <AdminShell><Space orientation="vertical" size="large" style={{ width: "100%" }}>
    <div><Title level={2}>OTC 大宗交易审核</Title><Paragraph type="secondary">订单按提交时的报价审核，通过后自动结算资金并转入客户持仓。仅展示当前账号权限范围内的待审核订单。</Paragraph></div>
    {error && <Alert type="error" title={error} showIcon />}
    <Card><Space style={{ width: "100%", justifyContent: "flex-end", marginBottom: 16 }}><Button icon={<ReloadOutlined />} loading={loading} onClick={load}>刷新</Button></Space><Table rowKey="id" columns={columns} dataSource={items} loading={loading} locale={{emptyText: '暂无待审核的 OTC 订单'}} pagination={{showTotal: total => `共 ${total} 条订单`}} scroll={{ x: 1250 }} /></Card>
  </Space></AdminShell>;
}
