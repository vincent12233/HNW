"use client";

import { DeleteOutlined, EditOutlined, PlusOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Card, Form, Input, InputNumber, Modal, Popconfirm, Select, Space, Table, Tag, Tooltip, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api, getApiErrorMessage } from "@/lib/api";

const { Text } = Typography;

type Strategy = {
  id: string;
  code: string;
  name: string;
  market: string;
  risk: string;
  annualReturn: number;
  maxDrawdown: number;
  authorizedClients: number;
  status: string;
};

export default function QuantPage() {
  const [items, setItems] = useState<Strategy[]>([]);
  const [keyword, setKeyword] = useState("");
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Strategy | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [form] = Form.useForm();

  async function loadItems() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<Strategy[]>("/admin-products/quant");
      setItems(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "量化策略加载失败"));
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
    return items.filter((item) => [item.code, item.name, item.market, item.status].some((field) => field.toLowerCase().includes(value)));
  }, [items, keyword]);

  function openCreate() {
    setEditing(null);
    form.resetFields();
    form.setFieldsValue({ market: "NSE", risk: "中" });
    setOpen(true);
  }

  function openEdit(record: Strategy) {
    setEditing(record);
    form.setFieldsValue(record);
    setOpen(true);
  }

  async function submitStrategy() {
    const values = form.getFieldsValue();
    const payload = {
      ...values,
      annualReturn: Number(values.annualReturn).toFixed(2),
      maxDrawdown: Number(values.maxDrawdown).toFixed(2),
    };
    if (editing) {
      await api.patch(`/admin-products/quant/${editing.id}`, payload);
      message.success("量化策略已更新");
    } else {
      await api.post("/admin-products/quant", payload);
      message.success("量化策略已新增");
    }
    setOpen(false);
    setEditing(null);
    form.resetFields();
    await loadItems();
  }

  async function deleteStrategy(record: Strategy) {
    await api.delete(`/admin-products/quant/${record.id}`);
    await loadItems();
    message.success("量化策略已删除");
  }

  const columns: ColumnsType<Strategy> = [
    { title: "策略编号", dataIndex: "code", width: 150, fixed: "left", render: (value) => <Text copyable>{value}</Text> },
    { title: "策略名称", dataIndex: "name", width: 260 },
    { title: "市场", dataIndex: "market", width: 120 },
    { title: "风险", dataIndex: "risk", width: 90, render: (value) => <Tag color={value === "高" ? "red" : value === "中" ? "gold" : "green"}>{value}</Tag> },
    { title: "年化收益", dataIndex: "annualReturn", width: 120, align: "right", render: (value) => `${value}%` },
    { title: "最大回撤", dataIndex: "maxDrawdown", width: 120, align: "right", render: (value) => `${value}%` },
    { title: "授权客户", dataIndex: "authorizedClients", width: 120, align: "right" },
    { title: "状态", dataIndex: "status", width: 110, render: (value) => <Tag color={value === "运行中" ? "green" : value === "观察中" ? "gold" : "default"}>{value}</Tag> },
    {
      title: "操作",
      width: 180,
      render: (_, record) => (
        <Space>
          <Button size="small" icon={<EditOutlined />} aria-label={`编辑 ${record.code}`} onClick={() => openEdit(record)}>编辑</Button>
          <Button size="small" onClick={async () => { await api.patch(`/admin-products/quant/${record.id}/status`, { status: "运行中" }); await loadItems(); }}>运行</Button>
          <Button size="small" danger onClick={async () => { await api.patch(`/admin-products/quant/${record.id}/status`, { status: "暂停" }); await loadItems(); }}>暂停</Button>
          <Popconfirm title="确认删除这个量化策略？" okText="删除" cancelText="取消" onConfirm={() => deleteStrategy(record)}>
            <Tooltip title="删除量化策略">
              <Button size="small" danger icon={<DeleteOutlined />} aria-label={`删除 ${record.code}`} />
            </Tooltip>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title="量化后台"
          crumbs={[{ title: "产品上架" }, { title: "量化策略" }]}
          description="仅后台管理量化策略、授权规模、收益指标和风控状态，不在客户 App 单独展示。VIP 在此页没有特殊用途。"
          extra={
            <Button type="primary" icon={<PlusOutlined />} onClick={openCreate} aria-label="新增量化策略">新增策略</Button>
          }
        />
        {error ? <OpsErrorState title={error} onRetry={() => void loadItems()} /> : null}
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input prefix={<SearchOutlined />} allowClear placeholder="搜索策略编号、名称、市场或状态" value={keyword} onChange={(event) => setKeyword(event.target.value)} aria-label="搜索已加载量化策略" style={{ width: 380, maxWidth: "100%" }} />
            <Button type="primary" icon={<PlusOutlined />} onClick={openCreate} aria-label="新增量化策略">新增策略</Button>
          </Space>
          <Table rowKey="id" className="ops-directory-table" columns={columns} dataSource={filtered} loading={loading} scroll={{ x: 1300 }} locale={{ emptyText: <OpsEmpty description={loading ? "正在加载量化策略" : "当前没有量化策略。"} onRetry={loading ? undefined : () => void loadItems()} /> }} />
        </Card>
      </Space>
      <Modal title={editing ? "编辑量化策略" : "新增量化策略"} open={open} onCancel={() => { setOpen(false); setEditing(null); }} onOk={() => form.validateFields().then(submitStrategy)} okText="保存" cancelText="取消">
        <Form form={form} layout="vertical">
          <Form.Item name="code" label="策略编号" rules={[{ required: true, message: "请输入策略编号" }]}><Input /></Form.Item>
          <Form.Item name="name" label="策略名称" rules={[{ required: true, message: "请输入策略名称" }]}><Input /></Form.Item>
          <Form.Item name="market" label="市场" initialValue="NSE"><Input /></Form.Item>
          <Form.Item name="risk" label="风险等级" initialValue="中"><Select options={[{ value: "低" }, { value: "中" }, { value: "高" }]} /></Form.Item>
          <Form.Item name="annualReturn" label="年化收益 %" rules={[{ required: true, message: "请输入年化收益" }]}><InputNumber precision={2} style={{ width: "100%" }} /></Form.Item>
          <Form.Item name="maxDrawdown" label="最大回撤 %" rules={[{ required: true, message: "请输入最大回撤" }]}><InputNumber min={0} precision={2} style={{ width: "100%" }} /></Form.Item>
        </Form>
      </Modal>
    </AdminShell>
  );
}
