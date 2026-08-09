"use client";

import { DeleteOutlined, EditOutlined, PlusOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Card, Form, Input, InputNumber, Modal, Popconfirm, Select, Space, Table, Tag, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type Deal = { id: string; orderNo: string; symbol: string; side: string; quantity: number; price: number; minTicket: number; status: string; note: string };

function money(value: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 }).format(value);
}

export default function BlockTradesPage() {
  const [items, setItems] = useState<Deal[]>([]);
  const [keyword, setKeyword] = useState("");
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Deal | null>(null);
  const [loading, setLoading] = useState(false);
  const [form] = Form.useForm();

  async function loadItems() {
    setLoading(true);
    try {
      const response = await api.get<Deal[]>("/admin-products/block-trades");
      setItems(Array.isArray(response.data) ? response.data : []);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadItems();
  }, []);

  const filtered = useMemo(() => {
    const value = keyword.trim().toLowerCase();
    if (!value) return items;
    return items.filter((item) => [item.orderNo, item.symbol, item.side, item.status].some((field) => field.toLowerCase().includes(value)));
  }, [items, keyword]);

  function openCreate() {
    setEditing(null);
    form.resetFields();
    form.setFieldsValue({ side: "买入" });
    setOpen(true);
  }

  function openEdit(record: Deal) {
    setEditing(record);
    form.setFieldsValue(record);
    setOpen(true);
  }

  async function submitDeal() {
    const values = form.getFieldsValue();
    if (editing) {
      await api.patch(`/admin-products/block-trades/${editing.id}`, values);
      message.success("大宗交易已更新");
    } else {
      await api.post("/admin-products/block-trades", values);
      message.success("大宗交易已创建");
    }
    setOpen(false);
    setEditing(null);
    form.resetFields();
    await loadItems();
  }

  async function deleteDeal(record: Deal) {
    await api.delete(`/admin-products/block-trades/${record.id}`);
    await loadItems();
    message.success("大宗交易已删除");
  }

  const columns: ColumnsType<Deal> = [
    { title: "订单号", dataIndex: "orderNo", width: 190, fixed: "left", render: (value) => <Text copyable>{value}</Text> },
    { title: "标的", dataIndex: "symbol", width: 130 },
    { title: "方向", dataIndex: "side", width: 90, render: (value) => <Tag color={value === "买入" ? "green" : "red"}>{value}</Tag> },
    { title: "数量", dataIndex: "quantity", width: 120, align: "right" },
    { title: "报价", dataIndex: "price", width: 140, align: "right", render: money },
    { title: "最低参与金额", dataIndex: "minTicket", width: 160, align: "right", render: money },
    { title: "状态", dataIndex: "status", width: 120, render: (value) => <Tag color={value === "开放" ? "green" : "gold"}>{value}</Tag> },
    { title: "备注", dataIndex: "note", width: 220 },
    {
      title: "操作",
      width: 160,
      render: (_, record) => (
        <Space>
          <Button size="small" icon={<EditOutlined />} onClick={() => openEdit(record)}>编辑</Button>
          <Button size="small" onClick={async () => { await api.patch(`/admin-products/block-trades/${record.id}/status`, { status: "开放" }); await loadItems(); }}>开放</Button>
          <Button size="small" danger onClick={async () => { await api.patch(`/admin-products/block-trades/${record.id}/status`, { status: "关闭" }); await loadItems(); }}>关闭</Button>
          <Popconfirm title="确认删除这条大宗交易？" okText="删除" cancelText="取消" onConfirm={() => deleteDeal(record)}>
            <Button size="small" danger icon={<DeleteOutlined />} />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>大宗交易后台</Title>
          <Paragraph type="secondary">仅后台维护大宗交易机会、报价、额度和状态，不在客户 App 公开展示。</Paragraph>
        </div>
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input prefix={<SearchOutlined />} allowClear placeholder="搜索订单号、标的或状态" value={keyword} onChange={(event) => setKeyword(event.target.value)} style={{ width: 360 }} />
            <Button type="primary" icon={<PlusOutlined />} onClick={openCreate}>新增大宗交易</Button>
          </Space>
          <Table rowKey="id" columns={columns} dataSource={filtered} loading={loading} scroll={{ x: 1340 }} />
        </Card>
      </Space>
      <Modal title={editing ? "编辑大宗交易" : "新增大宗交易"} open={open} onCancel={() => { setOpen(false); setEditing(null); }} onOk={() => form.validateFields().then(submitDeal)} okText="保存" cancelText="取消">
        <Form form={form} layout="vertical">
          <Form.Item name="symbol" label="标的代码" rules={[{ required: true, message: "请输入标的代码" }]}><Input /></Form.Item>
          <Form.Item name="side" label="方向" initialValue="买入"><Select options={[{ value: "买入" }, { value: "卖出" }]} /></Form.Item>
          <Form.Item name="quantity" label="数量" rules={[{ required: true, message: "请输入数量" }]}><InputNumber min={1} style={{ width: "100%" }} /></Form.Item>
          <Form.Item name="price" label="报价" rules={[{ required: true, message: "请输入报价" }]}><InputNumber min={0.01} precision={2} style={{ width: "100%" }} /></Form.Item>
          <Form.Item name="minTicket" label="最低参与金额" rules={[{ required: true, message: "请输入最低参与金额" }]}><InputNumber min={0.01} precision={2} style={{ width: "100%" }} /></Form.Item>
          <Form.Item name="note" label="备注"><Input.TextArea rows={3} /></Form.Item>
        </Form>
      </Modal>
    </AdminShell>
  );
}
