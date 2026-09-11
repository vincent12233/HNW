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
    Modal.success({ title: "OTC 上架成功 · 新交易密钥", content: <Space orientation="vertical"><Text>该 4 位交易密钥将在 OTC 列表中显示，下架后隐藏。</Text><Title level={2} copyable style={{ margin: 0, letterSpacing: 8 }}>{response.data.transactionKey}</Title></Space> });
  }
  async function toggle(record: Offer, isActive: boolean) {
    await api.patch(`/otc/admin/offers/${record.id}`, { isActive }); await load();
  }
  return <AdminShell><Space orientation="vertical" size="large" style={{ width: "100%" }}>
    <div><Title level={2}>OTC 上架管理</Title><Paragraph type="secondary">使用实时市场价格上架股票，每次上架自动生成新的 4 位交易密钥。</Paragraph></div>
    <Card><Space style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}><Button icon={<ReloadOutlined />} onClick={load}>刷新</Button><Button type="primary" icon={<PlusOutlined />} onClick={() => setOpen(true)}>上架股票</Button></Space>
      <Table rowKey="id" loading={loading} dataSource={offers} columns={[
        { title: "股票", render: (_: unknown, r: Offer) => <Space orientation="vertical" size={0}><Text strong>{r.instrument.symbol}</Text><Text type="secondary">{r.instrument.exchange} · {r.instrument.name}</Text></Space> },
        { title: "价格来源", render: () => <Tag color="blue">实时行情</Tag> },
        { title: "交易密钥", render: (_: unknown, r: Offer) => r.isActive && r.transactionKey ? <Text code copyable>{r.transactionKey}</Text> : <Text type="secondary">下架后隐藏</Text> },
        { title: "开始时间", dataIndex: "validFrom", render: (v: string) => new Date(v).toLocaleString("zh-CN") },
        { title: "结束时间", dataIndex: "validUntil", render: (v: string) => new Date(v).toLocaleString("zh-CN") },
        { title: "状态", render: (_: unknown, r: Offer) => <Tag color={r.isActive ? "green" : "default"}>{r.isActive ? "已上架" : "已下架"}</Tag> },
        { title: "启用", render: (_: unknown, r: Offer) => <Switch checked={r.isActive} onChange={(v) => toggle(r, v)} /> },
      ]} />
    </Card>
    <Modal title="上架 OTC 股票" open={open} onCancel={() => setOpen(false)} onOk={create} okText="上架并生成密钥" cancelText="取消"><Form form={form} layout="vertical">
      <Form.Item name="instrumentId" label="股票" rules={[{ required: true }]}><Select showSearch optionFilterProp="label" options={instruments.map((i) => ({ value: i.id, label: `${i.exchange}:${i.symbol} · ${i.name}` }))} /></Form.Item>
      <Form.Item name="period" label="有效时间" rules={[{ required: true }]}><DatePicker.RangePicker showTime style={{ width: "100%" }} /></Form.Item>
    </Form></Modal>
  </Space></AdminShell>;
}
