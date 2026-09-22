"use client";

import { DeleteOutlined, EditOutlined, PlusOutlined, ReloadOutlined, SearchOutlined, StarOutlined } from "@ant-design/icons";
import { Button, Card, Form, Input, InputNumber, Popconfirm, Segmented, Select, Space, Table, Tag, Tooltip, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsModal from "@/components/OpsModal";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api, getApiErrorMessage } from "@/lib/api";

const { Text } = Typography;

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
  const [error, setError] = useState("");
  const [form] = Form.useForm();
  const [saving, setSaving] = useState(false);
  const saveLock = useRef(false);
  const actionLock = useRef(false);
  const [actionId, setActionId] = useState<string | null>(null);

  async function loadItems() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<WatchItem[]>("/admin-products/watchlist");
      setItems(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "涨停股加载失败"));
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
    form.setFieldsValue({ market: "NSE", category: "INSTITUTIONAL", risk: "MEDIUM", direction: "UP", expectedReturn: 5 });
    setOpen(true);
  }

  function openEdit(record: WatchItem) {
    setEditing(record);
    form.setFieldsValue(record);
    setOpen(true);
  }

  async function submitItem() {
    if (saveLock.current) return;
    saveLock.current = true;
    setSaving(true);
    try {
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
        message.success("涨停股已更新");
      } else {
        await api.post("/admin-products/watchlist", payload);
        message.success("涨停股已上架");
      }
      setOpen(false);
      setEditing(null);
      form.resetFields();
      await loadItems();
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "涨停股保存失败，请重试"));
    } finally {
      saveLock.current = false;
      setSaving(false);
    }
  }

  async function runRowAction(record: WatchItem, action: () => Promise<unknown>, success: string) {
    if (actionLock.current) return false;
    actionLock.current = true;
    setActionId(record.id);
    try {
      await action();
      message.success(success);
      await loadItems();
      return true;
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "操作失败，请重试"));
      return false;
    } finally {
      actionLock.current = false;
      setActionId(null);
    }
  }

  async function deleteItem(record: WatchItem) {
    return runRowAction(record, () => api.delete(`/admin-products/watchlist/${record.id}`), "涨停股已删除");
  }

  async function changeStatus(record: WatchItem, status: string) {
    await runRowAction(record, () => api.patch(`/admin-products/watchlist/${record.id}/status`, { status }), "状态已更新");
  }

  const columns: ColumnsType<WatchItem> = [
    { title: "代码", dataIndex: "symbol", width: 130, fixed: "left", render: (value) => <Text strong>{value}</Text> },
    { title: "名称", dataIndex: "name", width: 220 },
    {
      title: "市场",
      dataIndex: "market",
      width: 100,
      render: (value) => <Tag color={value === "BSE" ? "purple" : "blue"}>{value || "NSE"}</Tag>,
    },
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
          <Button size="small" disabled={actionId !== null} icon={<EditOutlined />} aria-label={`编辑 ${record.symbol}`} onClick={() => openEdit(record)}>编辑</Button>
          <Button
            size="small"
            loading={actionId === record.id}
            disabled={actionId !== null}
            onClick={() => void changeStatus(record, record.status === "ACTIVE" ? "PAUSED" : "ACTIVE")}
          >
            {record.status === "ACTIVE" ? "暂停" : "展示"}
          </Button>
          <Popconfirm title="确认删除这条涨停股？" okText="删除" cancelText="取消" onConfirm={() => deleteItem(record)}>
            <Tooltip title="删除涨停股">
              <Button size="small" disabled={actionId !== null} danger icon={<DeleteOutlined />} aria-label={`删除 ${record.symbol}`} />
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
          title="涨停股上架"
          crumbs={[{ title: "产品上架" }, { title: "涨停股上架" }]}
          description="仅管理员可以新增、上架或下架涨停股（机构股票）；业务员和客户端只能查看已上架项目。涨停股成交按实时行情结算。客户端「自选股」是普通股票关注列表，与涨停股无关。"
          extra={
            <Space>
              <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void loadItems()} aria-label="刷新涨停股">刷新</Button>
              <Button type="primary" icon={<PlusOutlined />} onClick={openCreate} aria-label="新增涨停股">新增涨停股</Button>
            </Space>
          }
        />
        {error ? <OpsErrorState title={error} onRetry={() => void loadItems()} /> : null}
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input prefix={<SearchOutlined />} allowClear placeholder="搜索代码、名称、分类或状态" value={keyword} onChange={(event) => setKeyword(event.target.value)} aria-label="搜索已加载涨停股" style={{ width: 360, maxWidth: "100%" }} />
          </Space>
          <Table rowKey="id" className="ops-directory-table" columns={columns} dataSource={filtered} loading={loading} scroll={{ x: 1020 }} locale={{ emptyText: <OpsEmpty description={loading ? "正在加载涨停股" : keyword.trim() ? "没有匹配的结果，请调整或清空搜索条件。" : "当前没有涨停股。"} extra={!loading && keyword.trim() ? <Button onClick={() => setKeyword("")}>清空搜索</Button> : undefined} onRetry={loading || keyword.trim() ? undefined : () => void loadItems()} /> }} />
        </Card>
      </Space>

      <OpsModal title={editing ? "编辑涨停股" : "新增涨停股"} open={open} confirmLoading={saving} cancelButtonProps={{ disabled: saving }} closable={!saving} keyboard={!saving} onCancel={() => { if (saveLock.current) return; setOpen(false); setEditing(null); }} onOk={() => form.submit()} okText="保存" cancelText="取消">
        <Form form={form} layout="vertical" disabled={saving} onFinish={submitItem}>
          <Form.Item name="symbol" label="股票代码" rules={[{ required: true, message: "请输入股票代码" }]}><Input prefix={<StarOutlined />} /></Form.Item>
          <Form.Item name="name" label="股票名称" rules={[{ required: true, message: "请输入股票名称" }]}><Input /></Form.Item>
          <Form.Item
            name="market"
            label="市场"
            initialValue="NSE"
            rules={[{ required: true, message: "请选择市场" }]}
            extra="可在 NSE / BSE 之间切换；成交仍按对应交易所实时行情结算。"
          >
            <Segmented options={[{ label: "NSE", value: "NSE" }, { label: "BSE", value: "BSE" }]} block />
          </Form.Item>
          <Form.Item name="category" label="分类（涨停股 / 机构股票）" initialValue="INSTITUTIONAL"><Input disabled /></Form.Item>
          <Form.Item name="direction" label="买入方向" rules={[{ required: true }]}><Select options={[{ value: "UP", label: "上涨 Upward" }, { value: "DOWN", label: "下跌 Downward" }]} /></Form.Item>
          <Form.Item name="expectedReturn" label="预期短期收益（%）">
            <InputNumber min={0.01} max={100} precision={2} style={{ width: 180 }} />
          </Form.Item>
          <Form.Item name="risk" label="风险等级"><Select options={[{ value: "LOW", label: "低" }, { value: "MEDIUM", label: "中" }, { value: "HIGH", label: "高" }]} /></Form.Item>
          <Form.Item name="reason" label="推荐理由"><Input.TextArea rows={3} /></Form.Item>
        </Form>
      </OpsModal>
    </AdminShell>
  );
}
