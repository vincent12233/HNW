"use client";

import { DeleteOutlined, EditOutlined, PlusOutlined, SearchOutlined } from "@ant-design/icons";
import { Button, Form, Input, InputNumber, Select, Space, Table, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api } from "@/lib/api";
import { filterLoadedRows } from "@/lib/ops-directory";
import { OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { PRODUCT_COPY } from "@/lib/ops-product";

const { Text } = Typography;

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

export default function FundsPage() {
  const [items, setItems] = useState<FundProduct[]>([]);
  const [keyword, setKeyword] = useState("");
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<FundProduct | null>(null);
  const [deleting, setDeleting] = useState<FundProduct | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [form] = Form.useForm();

  async function loadItems() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<FundProduct[]>("/admin-products/funds");
      setItems(Array.isArray(response.data) ? response.data : []);
    } catch {
      setError("基金产品加载失败");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadItems();
  }, []);

  const filtered = useMemo(
    () => filterLoadedRows(items, keyword, (item) => [item.code, item.name, item.type, item.status, item.manager]),
    [items, keyword],
  );

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
    { title: "基金名称", dataIndex: "name", width: 260, render: (value) => <span className="ops-wrap-text">{value}</span> },
    { title: "类型", dataIndex: "type", width: 110 },
    { title: "净值", dataIndex: "nav", width: 100, align: "right", render: (value) => Number(value).toFixed(4) },
    { title: "最低申购", dataIndex: "minSubscribe", width: 150, align: "right", render: (value) => <OpsMoney value={value} /> },
    { title: "风险", dataIndex: "risk", width: 90, render: (value: string) => <OpsStatusTag code={value === "高" ? "OVERDUE" : value === "中" ? "PENDING" : "APPROVED"} label={value} /> },
    { title: "状态", dataIndex: "status", width: 120, render: (value: string) => <OpsStatusTag code={value === "开放申购" ? "ACTIVE" : "PAUSED"} label={value} /> },
    { title: "管理人", dataIndex: "manager", width: 180, render: (value) => value || "—" },
    {
      title: "操作",
      width: 220,
      render: (_, record) => (
        <Space>
          <Button size="small" icon={<EditOutlined />} aria-label={`编辑 ${record.code}`} onClick={() => openEdit(record)}>编辑</Button>
          <Button
            size="small"
            aria-label={record.status === "开放申购" ? `暂停 ${record.code}` : `开放 ${record.code}`}
            onClick={async () => {
              await api.patch(`/admin-products/funds/${record.id}/status`, {
                status: record.status === "开放申购" ? "暂停申购" : "开放申购",
              });
              await loadItems();
            }}
          >
            {record.status === "开放申购" ? "暂停" : "开放"}
          </Button>
          <Button size="small" danger icon={<DeleteOutlined />} aria-label={`删除 ${record.code}`} onClick={() => setDeleting(record)} />
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title={PRODUCT_COPY.fundsTitle}
          crumbs={[{ title: "产品" }, { title: PRODUCT_COPY.fundsTitle }]}
          description={`仅后台管理基金产品、净值、风险等级和申购状态，不在客户 App 单独展示。${PRODUCT_COPY.catalogNotTraded} ${PRODUCT_COPY.noVip}`}
        />
        {error ? <OpsErrorState title={error} onRetry={loadItems} /> : null}
        <OpsToolbar extra={<Button type="primary" icon={<PlusOutlined />} onClick={openCreate} aria-label="新增基金">新增基金</Button>}>
          <Input prefix={<SearchOutlined aria-hidden />} allowClear placeholder="搜索已加载的基金代码、名称、类型或状态" value={keyword} onChange={(event) => setKeyword(event.target.value)} aria-label="搜索已加载的基金产品" style={{ width: 380, maxWidth: "100%" }} />
        </OpsToolbar>
        <Text type="secondary">{PRODUCT_COPY.loadedFilter}</Text>
        <Table rowKey="id" className="ops-directory-table" columns={columns} dataSource={filtered} loading={loading} scroll={{ x: 1380 }} pagination={OPS_TABLE_PAGINATION} locale={{ emptyText: <OpsEmpty description={loading ? "正在加载基金产品" : "当前没有基金产品。"} onRetry={loading ? undefined : loadItems} /> }} />
      </Space>
      <OpsModal title={editing ? "编辑基金产品" : "新增基金产品"} open={open} onCancel={() => { setOpen(false); setEditing(null); }} onOk={() => form.validateFields().then(submitFund)} okText="保存" cancelText="返回" zIndex={2100}>
        <Form form={form} layout="vertical">
          <Form.Item name="code" label="基金代码" rules={[{ required: true, message: "请输入基金代码" }]}><Input /></Form.Item>
          <Form.Item name="name" label="基金名称" rules={[{ required: true, message: "请输入基金名称" }]}><Input /></Form.Item>
          <Form.Item name="type" label="类型" initialValue="股票型"><Select options={[{ value: "股票型" }, { value: "债券型" }, { value: "混合型" }, { value: "货币型" }]} /></Form.Item>
          <Form.Item name="nav" label="当前净值" rules={[{ required: true, message: "请输入净值" }]}><InputNumber min={0.01} precision={4} style={{ width: "100%" }} /></Form.Item>
          <Form.Item name="minSubscribe" label="最低申购金额" rules={[{ required: true, message: "请输入最低申购金额" }]}><InputNumber min={1} precision={2} style={{ width: "100%" }} /></Form.Item>
          <Form.Item name="risk" label="风险等级" initialValue="中"><Select options={[{ value: "低" }, { value: "中" }, { value: "高" }]} /></Form.Item>
          <Form.Item name="manager" label="管理人"><Input /></Form.Item>
        </Form>
      </OpsModal>
      <OpsModal
        title="确认删除基金产品"
        open={!!deleting}
        onCancel={() => setDeleting(null)}
        onOk={() => deleting && deleteFund(deleting).then(() => setDeleting(null))}
        okText="提交到服务器"
        cancelText="返回"
        okButtonProps={{ danger: true }}
        zIndex={2100}
      >
        <Text>删除 {deleting?.code} {deleting?.name}。目录删除不是交易或结算。</Text>
      </OpsModal>
    </AdminShell>
  );
}
