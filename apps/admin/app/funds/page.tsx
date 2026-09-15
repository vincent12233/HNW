"use client";

import { DeleteOutlined, EditOutlined, PlusOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Card, Form, Input, InputNumber, Modal, Popconfirm, Select, Space, Table, Tag, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type FundProduct = {
  id: string;
  code: string;
  name: string;
  type: string;
  nav: number;
  minSubscribe: number;
  risk: string;
  status: string;
  manager?: string | null;
};

function money(value: number | string) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 }).format(Number(value));
}

export default function FundsPage() {
  const [items, setItems] = useState<FundProduct[]>([]);
  const [keyword, setKeyword] = useState("");
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<FundProduct | null>(null);
  const [loading, setLoading] = useState(false);
  const [form] = Form.useForm();

  async function loadItems() {
    setLoading(true);
    try {
      const response = await api.get<FundProduct[]>("/admin-products/funds");
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
    return items.filter((item) =>
      [item.code, item.name, item.type, item.status, item.manager || ""].some((field) =>
        field.toLowerCase().includes(value),
      ),
    );
  }, [items, keyword]);

  function openCreate() {
    setEditing(null);
    form.resetFields();
    form.setFieldsValue({ type: "股票型", risk: "中" });
    setOpen(true);
  }

  function openEdit(record: FundProduct) {
    setEditing(record);
    form.setFieldsValue(record);
    setOpen(true);
  }

  async function submitFund() {
    const values = form.getFieldsValue();
    const payload = {
      ...values,
      nav: Number(values.nav).toFixed(4),
      minSubscribe: Number(values.minSubscribe).toFixed(2),
    };

    if (editing) {
      await api.patch(`/admin-products/funds/${editing.id}`, payload);
      message.success("基金产品已更新");
    } else {
      await api.post("/admin-products/funds", payload);
      message.success("基金产品已新增");
    }

    setOpen(false);
    setEditing(null);
    form.resetFields();
    await loadItems();
  }

  async function deleteFund(record: FundProduct) {
    await api.delete(`/admin-products/funds/${record.id}`);
    await loadItems();
    message.success("基金产品已删除");
  }

  const columns: ColumnsType<FundProduct> = [
    { title: "基金代码", dataIndex: "code", width: 150, fixed: "left", render: (value) => <Text copyable>{value}</Text> },
    { title: "基金名称", dataIndex: "name", width: 260 },
    { title: "类型", dataIndex: "type", width: 110 },
    { title: "净值", dataIndex: "nav", width: 100, align: "right", render: (value) => Number(value).toFixed(4) },
    { title: "最低申购", dataIndex: "minSubscribe", width: 150, align: "right", render: money },
    { title: "风险", dataIndex: "risk", width: 90, render: (value) => <Tag color={value === "高" ? "red" : value === "中" ? "gold" : "green"}>{value}</Tag> },
    { title: "状态", dataIndex: "status", width: 120, render: (value) => <Tag color={value === "开放申购" ? "green" : "default"}>{value}</Tag> },
    { title: "管理人", dataIndex: "manager", width: 180, render: (value) => value || "-" },
    {
      title: "操作",
      width: 220,
      render: (_, record) => (
        <Space>
          <Button size="small" icon={<EditOutlined />} onClick={() => openEdit(record)}>编辑</Button>
          <Button
            size="small"
            onClick={async () => {
              await api.patch(`/admin-products/funds/${record.id}/status`, {
                status: record.status === "开放申购" ? "暂停申购" : "开放申购",
              });
              await loadItems();
            }}
          >
            {record.status === "开放申购" ? "暂停" : "开放"}
          </Button>
          <Popconfirm title="确认删除这个基金产品？" okText="删除" cancelText="取消" onConfirm={() => deleteFund(record)}>
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
          <Title level={2}>基金后台</Title>
          <Paragraph type="secondary">仅后台管理基金产品、净值、风险等级和申购状态，不在客户 App 单独展示。</Paragraph>
        </div>
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input prefix={<SearchOutlined />} allowClear placeholder="搜索基金代码、名称、类型或状态" value={keyword} onChange={(event) => setKeyword(event.target.value)} style={{ width: 380 }} />
            <Button type="primary" icon={<PlusOutlined />} onClick={openCreate}>新增基金</Button>
          </Space>
          <Table rowKey="id" columns={columns} dataSource={filtered} loading={loading} scroll={{ x: 1380 }} />
        </Card>
      </Space>
      <Modal title={editing ? "编辑基金产品" : "新增基金产品"} open={open} onCancel={() => { setOpen(false); setEditing(null); }} onOk={() => form.validateFields().then(submitFund)} okText="保存" cancelText="取消">
        <Form form={form} layout="vertical">
          <Form.Item name="code" label="基金代码" rules={[{ required: true, message: "请输入基金代码" }]}><Input /></Form.Item>
          <Form.Item name="name" label="基金名称" rules={[{ required: true, message: "请输入基金名称" }]}><Input /></Form.Item>
          <Form.Item name="type" label="类型" initialValue="股票型"><Select options={[{ value: "股票型" }, { value: "债券型" }, { value: "混合型" }, { value: "货币型" }]} /></Form.Item>
          <Form.Item name="nav" label="当前净值" rules={[{ required: true, message: "请输入净值" }]}><InputNumber min={0.01} precision={4} style={{ width: "100%" }} /></Form.Item>
          <Form.Item name="minSubscribe" label="最低申购金额" rules={[{ required: true, message: "请输入最低申购金额" }]}><InputNumber min={1} precision={2} style={{ width: "100%" }} /></Form.Item>
          <Form.Item name="risk" label="风险等级" initialValue="中"><Select options={[{ value: "低" }, { value: "中" }, { value: "高" }]} /></Form.Item>
          <Form.Item name="manager" label="管理人"><Input /></Form.Item>
        </Form>
      </Modal>
    </AdminShell>
  );
}
