"use client";

import { PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import { Button, Card, DatePicker, Form, Modal, Select, Space, Switch, Table, Tag, Typography, message } from "antd";
import { useEffect, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;
type Instrument = { id: string; symbol: string; exchange: string; name: string };
type Offer = { id: string; price: string; transactionKey?: string | null; isActive: boolean; validFrom: string; validUntil: string; instrument: Instrument };
type PublishedOffer = Offer & { transactionKey: string };

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
    const response = await api.post<PublishedOffer>("/otc/admin/offers", {
      instrumentId: values.instrumentId,
      validFrom: values.period[0].toISOString(), validUntil: values.period[1].toISOString(),
    });
    setOpen(false); form.resetFields(); await load();
    Modal.success({ title: "OTC published · New transaction key", content: <Space orientation="vertical"><Text>This 4-digit key remains visible in the OTC list until the offer is delisted.</Text><Title level={2} copyable style={{ margin: 0, letterSpacing: 8 }}>{response.data.transactionKey}</Title></Space> });
  }
  async function toggle(record: Offer, isActive: boolean) {
    await api.patch(`/otc/admin/offers/${record.id}`, { isActive }); await load();
  }
  return <AdminShell><Space orientation="vertical" size="large" style={{ width: "100%" }}>
    <div><Title level={2}>OTC offers</Title><Paragraph type="secondary">Publish a stock using its live market price. A new random 4-digit transaction key is generated every time it is published.</Paragraph></div>
    <Card><Space style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}><Button icon={<ReloadOutlined />} onClick={load}>Refresh</Button><Button type="primary" icon={<PlusOutlined />} onClick={() => setOpen(true)}>Publish offer</Button></Space>
      <Table rowKey="id" loading={loading} dataSource={offers} columns={[
        { title: "Stock", render: (_: unknown, r: Offer) => <Space orientation="vertical" size={0}><Text strong>{r.instrument.symbol}</Text><Text type="secondary">{r.instrument.exchange} · {r.instrument.name}</Text></Space> },
        { title: "Price source", render: () => <Tag color="blue">LIVE MARKET</Tag> },
        { title: "Transaction key", render: (_: unknown, r: Offer) => r.isActive && r.transactionKey ? <Text code copyable>{r.transactionKey}</Text> : <Text type="secondary">Hidden after delisting</Text> },
        { title: "Valid from", dataIndex: "validFrom", render: (v: string) => new Date(v).toLocaleString() },
        { title: "Valid until", dataIndex: "validUntil", render: (v: string) => new Date(v).toLocaleString() },
        { title: "Status", render: (_: unknown, r: Offer) => <Tag color={r.isActive ? "green" : "default"}>{r.isActive ? "ACTIVE" : "CLOSED"}</Tag> },
        { title: "Enabled", render: (_: unknown, r: Offer) => <Switch checked={r.isActive} onChange={(v) => toggle(r, v)} /> },
      ]} />
    </Card>
    <Modal title="Publish OTC offer" open={open} onCancel={() => setOpen(false)} onOk={create} okText="Publish and generate key"><Form form={form} layout="vertical">
      <Form.Item name="instrumentId" label="Stock" rules={[{ required: true }]}><Select showSearch optionFilterProp="label" options={instruments.map((i) => ({ value: i.id, label: `${i.exchange}:${i.symbol} · ${i.name}` }))} /></Form.Item>
      <Form.Item name="period" label="Validity period" rules={[{ required: true }]}><DatePicker.RangePicker showTime style={{ width: "100%" }} /></Form.Item>
    </Form></Modal>
  </Space></AdminShell>;
}
