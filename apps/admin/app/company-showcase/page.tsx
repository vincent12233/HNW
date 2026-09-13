"use client";
import { useEffect, useState } from "react";
import { Button, Card, Form, Input, InputNumber, Modal, Space, Switch, Table, Tag, Typography, message } from "antd";
import { PlusOutlined, EditOutlined, DeleteOutlined } from "@ant-design/icons";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";
const { Title, Text } = Typography;
type Company = { id: string; name: string; tagline: string; description: string; logoUrl?: string; websiteUrl?: string; sector?: string; status: string; sortOrder: number };
export default function CompanyShowcasePage() {
  const [rows, setRows] = useState<Company[]>([]); const [open, setOpen] = useState(false); const [editing, setEditing] = useState<Company | null>(null); const [form] = Form.useForm();
  const load = async () => { const { data } = await api.get<Company[]>("/company-showcase/admin"); setRows(data); };
  useEffect(() => { load().catch(() => message.error("加载公司展示失败")); }, []);
  const save = async (values: any) => { const payload = { ...values, status: values.status ? "ACTIVE" : "INACTIVE" }; if (editing) await api.patch(`/company-showcase/${editing.id}`, payload); else await api.post("/company-showcase", payload); message.success("已保存"); setOpen(false); await load(); };
  const remove = (id: string) => Modal.confirm({ title: "删除平台公司信息？", content: "删除后首页将不再展示平台公司信息。", okButtonProps: { danger: true }, onOk: async () => { await api.delete(`/company-showcase/${id}`); await load(); } });
  return <AdminShell><Card><Space direction="vertical" size={18} style={{ width: "100%" }}><Space style={{ justifyContent: "space-between", width: "100%" }}><div><Title level={3} style={{ margin: 0 }}>公司信息</Title><Text type="secondary">维护客户端首页唯一展示的平台公司资料。</Text></div><Button type="primary" icon={<PlusOutlined />} onClick={() => { setEditing(null); form.resetFields(); form.setFieldValue("status", true); setOpen(true); }}>保存公司信息</Button></Space><Table rowKey="id" dataSource={rows.slice(0, 1)} columns={[{ title: "公司", render: (_, r) => <Space><Tag color={r.status === "ACTIVE" ? "green" : "default"}>{r.status}</Tag><div><b>{r.name}</b><div><Text type="secondary">{r.tagline}</Text></div></div></Space> }, { title: "行业", dataIndex: "sector" }, { title: "排序", dataIndex: "sortOrder" }, { title: "操作", render: (_, r) => <Space><Button icon={<EditOutlined />} onClick={() => { setEditing(r); form.setFieldsValue({ ...r, status: r.status === "ACTIVE" }); setOpen(true); }}>编辑</Button><Button danger icon={<DeleteOutlined />} onClick={() => remove(r.id)} /></Space> }]} /></Space></Card><Modal title={editing ? "编辑平台公司信息" : "平台公司信息"} open={open} onCancel={() => setOpen(false)} onOk={() => form.submit()} okText="保存"><Form form={form} layout="vertical" onFinish={save}><Form.Item name="name" label="公司名称" rules={[{ required: true }]}><Input /></Form.Item><Form.Item name="tagline" label="一句话介绍" rules={[{ required: true }]}><Input /></Form.Item><Form.Item name="description" label="公司简介" rules={[{ required: true }]}><Input.TextArea rows={4} /></Form.Item><Space style={{ width: "100%" }}><Form.Item name="sector" label="行业"><Input /></Form.Item><Form.Item name="sortOrder" label="排序"><InputNumber min={0} /></Form.Item></Space><Form.Item name="logoUrl" label="Logo URL"><Input placeholder="可选 HTTPS 图片地址" /></Form.Item><Form.Item name="websiteUrl" label="官网 URL"><Input placeholder="可选 HTTPS 链接" /></Form.Item><Form.Item name="status" label="首页展示" valuePropName="checked"><Switch /></Form.Item></Form></Modal></AdminShell>;
}


