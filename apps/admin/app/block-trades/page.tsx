"use client";

import { PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import { Button, Card, DatePicker, Form, Input, InputNumber, Modal, Select, Space, Switch, Table, Tag, Typography, message } from "antd";
import { useEffect, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;
type Instrument = { id: string; symbol: string; exchange: string; name: string };
type Offer = { id: string; price: string; priceTier2?: string; priceTier3?: string; profitTier1?: string; profitTier2?: string; profitTier3?: string; isActive: boolean; validFrom: string; validUntil: string; instrument: Instrument };
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
      instrumentId: values.instrumentId,
      tiers: [1, 2, 3].map((tier) => ({ price: String(values[`price${tier}`]), profit: String(values[`profit${tier}`]), transactionKey: values[`key${tier}`] })),
      validFrom: values.period[0].toISOString(), validUntil: values.period[1].toISOString(),
    });
    message.success("OTC three-tier offer published"); setOpen(false); form.resetFields(); await load();
  }
  async function toggle(record: Offer, isActive: boolean) {
    await api.patch(`/otc/admin/offers/${record.id}`, { isActive }); await load();
  }
  return <AdminShell><Space orientation="vertical" size="large" style={{ width: "100%" }}>
    <div><Title level={2}>OTC offers</Title><Paragraph type="secondary">Publish three purchase prices for each stock. Every entrance uses its own 6-digit transaction key; keys are encrypted and never shown in the App.</Paragraph></div>
    <Card><Space style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}><Button icon={<ReloadOutlined />} onClick={load}>Refresh</Button><Button type="primary" icon={<PlusOutlined />} onClick={() => setOpen(true)}>Publish offer</Button></Space>
      <Table rowKey="id" loading={loading} dataSource={offers} columns={[
        { title: "Stock", render: (_: unknown, r: Offer) => <Space orientation="vertical" size={0}><Text strong>{r.instrument.symbol}</Text><Text type="secondary">{r.instrument.exchange} · {r.instrument.name}</Text></Space> },
        { title: "Purchase prices", render: (_: unknown, r: Offer) => <Space orientation="vertical" size={0}><Text>1 · {money(r.price)} ({r.profitTier1 ?? "--"}%)</Text><Text>2 · {r.priceTier2 ? money(r.priceTier2) : "--"} ({r.profitTier2 ?? "--"}%)</Text><Text>3 · {r.priceTier3 ? money(r.priceTier3) : "--"} ({r.profitTier3 ?? "--"}%)</Text></Space> },
        { title: "Valid from", dataIndex: "validFrom", render: (v: string) => new Date(v).toLocaleString() },
        { title: "Valid until", dataIndex: "validUntil", render: (v: string) => new Date(v).toLocaleString() },
        { title: "Status", render: (_: unknown, r: Offer) => <Tag color={r.isActive ? "green" : "default"}>{r.isActive ? "ACTIVE" : "CLOSED"}</Tag> },
        { title: "Enabled", render: (_: unknown, r: Offer) => <Switch checked={r.isActive} onChange={(v) => toggle(r, v)} /> },
      ]} />
    </Card>
    <Modal title="Publish three-tier OTC offer" width={720} open={open} onCancel={() => setOpen(false)} onOk={create} okText="Publish"><Form form={form} layout="vertical">
      <Form.Item name="instrumentId" label="Stock" rules={[{ required: true }]}><Select showSearch optionFilterProp="label" options={instruments.map((i) => ({ value: i.id, label: `${i.exchange}:${i.symbol} · ${i.name}` }))} /></Form.Item>
      {[1, 2, 3].map((tier) => <Card key={tier} size="small" title={`Purchase entrance ${tier}`} style={{ marginBottom: 12 }}><Space align="start" wrap>
        <Form.Item name={`price${tier}`} label="OTC price" rules={[{ required: true }]}><InputNumber min={0.01} precision={4} prefix="₹" /></Form.Item>
        <Form.Item name={`profit${tier}`} label="Profit (%)" rules={[{ required: true }]}><InputNumber min={0.01} max={10000} precision={2} suffix="%" /></Form.Item>
        <Form.Item name={`key${tier}`} label="6-digit transaction key" rules={[{ required: true }, { pattern: /^\d{6}$/, message: "Enter 6 digits" }]}><Input.Password inputMode="numeric" maxLength={6} /></Form.Item>
      </Space></Card>)}
      <Form.Item name="period" label="Validity period" rules={[{ required: true }]}><DatePicker.RangePicker showTime style={{ width: "100%" }} /></Form.Item>
    </Form></Modal>
  </Space></AdminShell>;
}
