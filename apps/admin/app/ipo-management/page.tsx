"use client";

import { PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import { Button, Card, DatePicker, Form, Input, InputNumber, Modal, Select, Space, Table, Tag, Typography, message } from "antd";
import { useEffect, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;
type Instrument = { id: string; symbol: string; exchange: "NSE" | "BSE"; name: string };
type Ipo = { id: string; symbol: string; companyName: string; exchange: string; issuePrice: string; lotSize: number; totalShares: number; availableShares: number; openDate: string; closeDate: string; status: "DRAFT" | "OPEN" | "CLOSED" | "ALLOTMENT_DONE"; applicationCount: number };

export default function IpoManagementPage() {
  const [items, setItems] = useState<Ipo[]>([]);
  const [instruments, setInstruments] = useState<Instrument[]>([]);
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);
  const [form] = Form.useForm();

  async function load() {
    setLoading(true);
    try {
      const [ipoResponse, instrumentResponse] = await Promise.all([
        api.get<{ data: Ipo[] }>("/admin/ipo"),
        api.get<{ data: Instrument[] }>("/admin/market/instruments?pageSize=100"),
      ]);
      setItems(ipoResponse.data.data ?? []);
      setInstruments(instrumentResponse.data.data ?? []);
    } finally { setLoading(false); }
  }
  useEffect(() => { void load(); }, []);

  async function create() {
    const values = await form.validateFields();
    const instrument = instruments.find((item) => item.id === values.instrumentId)!;
    await api.post("/admin/ipo", {
      symbol: instrument.symbol,
      companyName: values.companyName,
      exchange: instrument.exchange,
      instrumentId: instrument.id,
      issuePrice: Number(values.issuePrice),
      lotSize: Number(values.lotSize),
      totalShares: Number(values.totalShares),
      openDate: values.period[0].toISOString(),
      closeDate: values.period[1].toISOString(),
    });
    message.success("IPO 已创建为草稿");
    setOpen(false); form.resetFields(); await load();
  }

  async function setStatus(record: Ipo, status: Ipo["status"]) {
    await api.patch(`/admin/ipo/${record.id}/status`, { status });
    message.success(status === "OPEN" ? "IPO 已上架" : status === "CLOSED" ? "IPO 已下架" : "状态已更新");
    await load();
  }

  return <AdminShell><Space orientation="vertical" size="large" style={{ width: "100%" }}>
    <div><Title level={2}>IPO 上架管理</Title><Paragraph type="secondary">仅管理员可以创建 IPO，并控制开放申购、关闭申购和完成配售。</Paragraph></div>
    <Card>
      <Space style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
        <Button icon={<ReloadOutlined />} onClick={load} loading={loading}>刷新</Button>
        <Button type="primary" icon={<PlusOutlined />} onClick={() => setOpen(true)}>创建 IPO</Button>
      </Space>
      <Table<Ipo> rowKey="id" loading={loading} dataSource={items} scroll={{ x: 1200 }} columns={[
        { title: "IPO", width: 220, render: (_, r) => <Space orientation="vertical" size={0}><Text strong>{r.symbol}</Text><Text type="secondary">{r.companyName}</Text></Space> },
        { title: "发行价", dataIndex: "issuePrice", width: 120 },
        { title: "每手", dataIndex: "lotSize", width: 90 },
        { title: "可用股数", dataIndex: "availableShares", width: 120 },
        { title: "申购数", dataIndex: "applicationCount", width: 90 },
        { title: "状态", dataIndex: "status", width: 130, render: (v) => <Tag color={v === "OPEN" ? "green" : v === "DRAFT" ? "gold" : "default"}>{v}</Tag> },
        { title: "申购期间", width: 310, render: (_, r) => `${new Date(r.openDate).toLocaleString()} — ${new Date(r.closeDate).toLocaleString()}` },
        { title: "操作", fixed: "right", width: 220, render: (_, r) => <Space><Button size="small" type="primary" disabled={r.status === "OPEN" || r.status === "ALLOTMENT_DONE"} onClick={() => setStatus(r, "OPEN")}>上架</Button><Button size="small" danger disabled={r.status !== "OPEN"} onClick={() => setStatus(r, "CLOSED")}>下架</Button></Space> },
      ]} />
    </Card>
    <Modal title="创建 IPO" open={open} onCancel={() => setOpen(false)} onOk={create} okText="创建草稿">
      <Form form={form} layout="vertical">
        <Form.Item name="instrumentId" label="关联股票" rules={[{ required: true }]}><Select showSearch optionFilterProp="label" options={instruments.map((i) => ({ value: i.id, label: `${i.exchange}:${i.symbol} · ${i.name}` }))} /></Form.Item>
        <Form.Item name="companyName" label="公司名称" rules={[{ required: true }]}><Input /></Form.Item>
        <Form.Item name="issuePrice" label="发行价" rules={[{ required: true }]}><InputNumber min={0.01} precision={2} style={{ width: "100%" }} /></Form.Item>
        <Form.Item name="lotSize" label="每手股数" rules={[{ required: true }]}><InputNumber min={1} precision={0} style={{ width: "100%" }} /></Form.Item>
        <Form.Item name="totalShares" label="发行总股数" rules={[{ required: true }]}><InputNumber min={1} precision={0} style={{ width: "100%" }} /></Form.Item>
        <Form.Item name="period" label="申购期间" rules={[{ required: true }]}><DatePicker.RangePicker showTime style={{ width: "100%" }} /></Form.Item>
      </Form>
    </Modal>
  </Space></AdminShell>;
}
