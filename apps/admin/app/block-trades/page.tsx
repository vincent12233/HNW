"use client";

import { PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import { Button, Card, DatePicker, Form, InputNumber, Modal, Select, Space, Switch, Table, Tag, Typography, message } from "antd";
import { useEffect, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;
type Instrument = { id: string; symbol: string; exchange: string; name: string };
type Offer = { id: string; price: string; isActive: boolean; validFrom: string; validUntil: string; instrument: Instrument };
const money = (v: string | number) => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(Number(v));

export default function OtcOffersPage() {
  const [offers, setOffers] = useState<Offer[]>([]);
  const [instruments, setInstruments] = useState<Instrument[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [form] = Form.useForm();
  async function load() {
    setLoading(true);
    try {
      const [offerResponse, instrumentResponse] = await Promise.all([
        api.get<Offer[]>("/otc/admin/offers"),
        api.get<{ data: Instrument[] }>("/admin/market/instruments?pageSize=100"),
      ]);
      setOffers(offerResponse.data ?? []); setInstruments(instrumentResponse.data.data ?? []);
    } finally { setLoading(false); }
  }
  useEffect(() => { void load(); }, []);
  async function create() {
    const values = await form.validateFields();
    await api.post("/otc/admin/offers", {
      instrumentId: values.instrumentId, price: String(values.price),
      validFrom: values.period[0].toISOString(), validUntil: values.period[1].toISOString(),
    });
    message.success("OTC backend price published"); setOpen(false); form.resetFields(); await load();
  }
  async function toggle(record: Offer, isActive: boolean) {
    await api.patch(`/otc/admin/offers/${record.id}`, { isActive }); await load();
  }
  return <AdminShell><Space orientation="vertical" size="large" style={{ width: "100%" }}>
    <div><Title level={2}>OTC offers</Title><Paragraph type="secondary">Publish the fixed backend price and validity period. Customers choose quantity; no minimum quantity or negotiation.</Paragraph></div>
    <Card><Space style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}><Button icon={<ReloadOutlined />} onClick={load}>Refresh</Button><Button type="primary" icon={<PlusOutlined />} onClick={() => setOpen(true)}>Publish offer</Button></Space>
      <Table rowKey="id" loading={loading} dataSource={offers} columns={[
        { title: "Stock", render: (_: unknown, r: Offer) => <Space orientation="vertical" size={0}><Text strong>{r.instrument.symbol}</Text><Text type="secondary">{r.instrument.exchange} · {r.instrument.name}</Text></Space> },
        { title: "Backend price", dataIndex: "price", align: "right", render: money },
        { title: "Valid from", dataIndex: "validFrom", render: (v: string) => new Date(v).toLocaleString() },
        { title: "Valid until", dataIndex: "validUntil", render: (v: string) => new Date(v).toLocaleString() },
        { title: "Status", render: (_: unknown, r: Offer) => <Tag color={r.isActive ? "green" : "default"}>{r.isActive ? "ACTIVE" : "CLOSED"}</Tag> },
        { title: "Enabled", render: (_: unknown, r: Offer) => <Switch checked={r.isActive} onChange={(v) => toggle(r, v)} /> },
      ]} />
    </Card>
    <Modal title="Publish OTC offer" open={open} onCancel={() => setOpen(false)} onOk={create} okText="Publish"><Form form={form} layout="vertical">
      <Form.Item name="instrumentId" label="Stock" rules={[{ required: true }]}><Select showSearch optionFilterProp="label" options={instruments.map((i) => ({ value: i.id, label: `${i.exchange}:${i.symbol} · ${i.name}` }))} /></Form.Item>
      <Form.Item name="price" label="Backend price" rules={[{ required: true }]}><InputNumber min={0.01} precision={4} style={{ width: "100%" }} /></Form.Item>
      <Form.Item name="period" label="Validity period" rules={[{ required: true }]}><DatePicker.RangePicker showTime style={{ width: "100%" }} /></Form.Item>
    </Form></Modal>
  </Space></AdminShell>;
}
