"use client";

import { DeleteOutlined, EditOutlined, PlusOutlined, ReloadOutlined, SearchOutlined, StarOutlined } from "@ant-design/icons";
import { Button, Card, Form, Input, InputNumber, Modal, Popconfirm, Select, Space, Table, Tag, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type WatchItem = {
  id: string;
  symbol: string;
  name: string;
  market: string;
  category: string;
  risk: string;
  status: string;
  reason: string;
  direction: "UP" | "DOWN";
  expectedReturn?: string | null;
};

export default function WatchlistPage() {
  const [items, setItems] = useState<WatchItem[]>([]);
  const [keyword, setKeyword] = useState("");
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<WatchItem | null>(null);
  const [loading, setLoading] = useState(false);
  const [form] = Form.useForm();

  async function loadItems() {
    setLoading(true);
    try {
      const response = await api.get<WatchItem[]>("/admin-products/watchlist");
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
      [item.symbol, item.name, item.market, item.category, item.status]
        .some((field) => field.toLowerCase().includes(value)),
    );
  }, [items, keyword]);

  function openCreate() {
    setEditing(null);
    form.resetFields();
    form.setFieldsValue({ market: "BSE", category: "INSTITUTIONAL", risk: "MEDIUM", direction: "UP", expectedReturn: 5 });
    setOpen(true);
  }

  function openEdit(record: WatchItem) {
    setEditing(record);
    form.setFieldsValue(record);
    setOpen(true);
  }

  async function submitItem() {
    const values = form.getFieldsValue();
    const payload = {
      ...values,
      expectedReturn:
        values.expectedReturn == null || values.expectedReturn === ''
          ? undefined
          : Number(values.expectedReturn).toFixed(2),
    };
    if (editing) {
      await api.patch(`/admin-products/watchlist/${editing.id}`, payload);
      message.success("Inst. 股票已更新");
    } else {
      await api.post("/admin-products/watchlist", payload);
      message.success("Inst. 股票已上架");
    }
    setOpen(false);
    setEditing(null);
    form.resetFields();
    await loadItems();
  }

  async function deleteItem(record: WatchItem) {
    await api.delete(`/admin-products/watchlist/${record.id}`);
    await loadItems();
    message.success("自选股已删除");
  }

  const columns: ColumnsType<WatchItem> = [
    { title: "代码", dataIndex: "symbol", width: 130, fixed: "left", render: (value) => <Text strong>{value}</Text> },
    { title: "名称", dataIndex: "name", width: 220 },
    { title: "市场", dataIndex: "market", width: 100 },
    { title: "分类", dataIndex: "category", width: 130 },
    { title: "方向", dataIndex: "direction", width: 90, render: (value) => <Tag color={value === "UP" ? "green" : "red"}>{value === "UP" ? "上涨" : "下跌"}</Tag> },
    { title: "预期收益", dataIndex: "expectedReturn", width: 100, render: (value) => value ? `${Number(value).toFixed(2)}%` : "-" },
    { title: "风险", dataIndex: "risk", width: 90, render: (value) => <Tag color={value === "HIGH" ? "red" : value === "MEDIUM" ? "gold" : "green"}>{value}</Tag> },
    { title: "状态", dataIndex: "status", width: 110, render: (value) => <Tag color={value === "ACTIVE" ? "green" : "default"}>{value === "ACTIVE" ? "展示中" : "已暂停"}</Tag> },
    { title: "推荐理由", dataIndex: "reason", width: 260 },
    {
      title: "操作",
      width: 120,
      render: (_, record) => (
        <Space>
          <Button size="small" icon={<EditOutlined />} onClick={() => openEdit(record)}>编辑</Button>
          <Button
            size="small"
            onClick={async () => {
              await api.patch(`/admin-products/watchlist/${record.id}/status`, {
                status: record.status === "ACTIVE" ? "PAUSED" : "ACTIVE",
              });
              await loadItems();
            }}
          >
            {record.status === "ACTIVE" ? "暂停" : "展示"}
          </Button>
          <Popconfirm title="确认删除这条自选股？" okText="删除" cancelText="取消" onConfirm={() => deleteItem(record)}>
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
          <Title level={2}>Inst. 上架管理</Title>
          <Paragraph type="secondary">
            仅管理员可以新增、上架或下架机构股票；业务员和客户端只能查看已上架项目。
            客户端成交价按实时行情结算，无需配置后台参考价。
          </Paragraph>
        </div>
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input prefix={<SearchOutlined />} allowClear placeholder="搜索代码、名称、分类或状态" value={keyword} onChange={(event) => setKeyword(event.target.value)} style={{ width: 360 }} />
            <Space>
              <Button icon={<ReloadOutlined />} loading={loading} onClick={loadItems}>刷新</Button>
              <Button type="primary" icon={<PlusOutlined />} onClick={openCreate}>新增 Inst. 股票</Button>
            </Space>
          </Space>
          <Table rowKey="id" columns={columns} dataSource={filtered} loading={loading} scroll={{ x: 1020 }} />
        </Card>
      </Space>

      <Modal title={editing ? "编辑自选股" : "新增自选股"} open={open} onCancel={() => { setOpen(false); setEditing(null); }} onOk={() => form.validateFields().then(submitItem)} okText="保存" cancelText="取消">
        <Form form={form} layout="vertical">
          <Form.Item name="symbol" label="股票代码" rules={[{ required: true, message: "请输入股票代码" }]}><Input prefix={<StarOutlined />} /></Form.Item>
          <Form.Item name="name" label="股票名称" rules={[{ required: true, message: "请输入股票名称" }]}><Input /></Form.Item>
          <Form.Item name="market" label="市场" initialValue="NSE"><Select options={[{ value: "NSE" }, { value: "BSE" }]} /></Form.Item>
          <Form.Item name="category" label="分类" initialValue="INSTITUTIONAL"><Input disabled /></Form.Item>
          <Form.Item name="direction" label="买入方向" rules={[{ required: true }]}><Select options={[{ value: "UP", label: "上涨 Upward" }, { value: "DOWN", label: "下跌 Downward" }]} /></Form.Item>
          <Form.Item name="expectedReturn" label="预期短期收益（%）">
            <InputNumber min={0.01} max={100} precision={2} style={{ width: 180 }} />
          </Form.Item>
          <Form.Item name="risk" label="风险等级"><Select options={[{ value: "LOW", label: "低" }, { value: "MEDIUM", label: "中" }, { value: "HIGH", label: "高" }]} /></Form.Item>
          <Form.Item name="reason" label="推荐理由"><Input.TextArea rows={3} /></Form.Item>
        </Form>
      </Modal>
    </AdminShell>
  );
}
