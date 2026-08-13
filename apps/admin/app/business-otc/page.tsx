"use client";

import { CheckOutlined, CloseOutlined, ReloadOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Space, Table, Tag, Typography, message } from "antd";
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

  async function load() {
    setLoading(true); setError("");
    try { const response = await api.get<OtcOrder[]>("/otc/orders/pending"); setItems(response.data ?? []); }
    catch (requestError: any) { setError(requestError.response?.data?.message ?? "OTC pending orders failed to load"); }
    finally { setLoading(false); }
  }
  useEffect(() => { void load(); }, []);

  async function review(id: string, decision: "approve" | "reject") {
    try {
      await api.patch(`/otc/orders/${id}/${decision}`, decision === "reject" ? { note: "Rejected by backend review" } : {});
      message.success(decision === "approve" ? "Approved and moved to holdings" : "Order rejected");
      await load();
    } catch (requestError: any) { message.error(requestError.response?.data?.message ?? "Review failed"); }
  }

  const columns: ColumnsType<OtcOrder> = [
    { title: "Order", dataIndex: "orderNo", width: 210, render: (v) => <Text copyable>{v}</Text> },
    { title: "Customer", width: 190, render: (_, r) => <Space orientation="vertical" size={0}><Text strong>{r.account.user.fullName}</Text><Text type="secondary">{r.account.accountNumber}</Text></Space> },
    { title: "Stock", width: 170, render: (_, r) => <Space orientation="vertical" size={0}><Text strong>{r.instrument.symbol}</Text><Text type="secondary">{r.instrument.name}</Text></Space> },
    { title: "Quantity", dataIndex: "quantity", align: "right", width: 100 },
    { title: "Backend price", dataIndex: "price", align: "right", width: 140, render: money },
    { title: "Amount", dataIndex: "amount", align: "right", width: 150, render: money },
    { title: "Status", dataIndex: "status", width: 120, render: (v) => <Tag color="gold">{v}</Tag> },
    { title: "Actions", fixed: "right", width: 190, render: (_, r) => <Space><Button type="primary" size="small" icon={<CheckOutlined />} onClick={() => review(r.id, "approve")}>Approve</Button><Button danger size="small" icon={<CloseOutlined />} onClick={() => review(r.id, "reject")}>Reject</Button></Space> },
  ];
  return <AdminShell><Space orientation="vertical" size="large" style={{ width: "100%" }}>
    <div><Title level={2}>OTC review</Title><Paragraph type="secondary">Customer orders use the backend price. Approval automatically settles funds and transfers the stock to holdings.</Paragraph></div>
    {error && <Alert type="error" title={error} showIcon />}
    <Card><Space style={{ width: "100%", justifyContent: "flex-end", marginBottom: 16 }}><Button icon={<ReloadOutlined />} onClick={load}>Refresh</Button></Space><Table rowKey="id" columns={columns} dataSource={items} loading={loading} scroll={{ x: 1250 }} /></Card>
  </Space></AdminShell>;
}
