"use client";

import { LockOutlined, ReloadOutlined, SearchOutlined, StopOutlined, UnlockOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Popconfirm, Space, Table, Tag, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { isAxiosError } from "axios";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type Customer = {
  id: string;
  customerNo?: string | null;
  fullName: string;
  phone?: string | null;
  status: string;
  createdAt: string;
  account?: {
    accountNumber: string;
    cashBalance: string | number;
    buyingPower: string | number;
    frozenBalance: string | number;
    currency: string;
  } | null;
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

function statusTag(status: string) {
  const map: Record<string, { color: string; label: string }> = {
    ACTIVE: { color: "green", label: "正常" },
    SUSPENDED: { color: "orange", label: "已冻结" },
    DISABLED: { color: "red", label: "已禁用" },
  };
  const config = map[status] ?? { color: "default", label: status };
  return <Tag color={config.color}>{config.label}</Tag>;
}

export default function BusinessAccountsPage() {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const mutationLock = useRef(false);
  const listRequest = useRef(0);
  const [saving, setSaving] = useState(false);

  const loadCustomers = useCallback(async () => {
    const request = ++listRequest.current;
    setLoading(true);
    setError("");
    try {
      const response = await api.get<Customer[]>("/business/my-customers");
      if (request !== listRequest.current) return;
      if (!Array.isArray(response.data)) throw new Error("Invalid accounts response");
      setCustomers(response.data);
    } catch (requestError: unknown) {
      if (request !== listRequest.current) return;
      const responseMessage = isAxiosError<{ message?: string | string[] }>(requestError) ? requestError.response?.data?.message : undefined;
      setError(Array.isArray(responseMessage) ? responseMessage.join("，") : (responseMessage || "账户列表加载失败"));
    } finally {
      if (request === listRequest.current) setLoading(false);
    }
  }, []);

  async function updateStatus(customerId: string, status: "ACTIVE" | "SUSPENDED" | "DISABLED") {
    if (mutationLock.current) return;
    mutationLock.current = true;
    setSaving(true);
    listRequest.current++;
    try {
      await api.patch(`/business/customers/${customerId}/status`, { status });
      setCustomers((rows) => rows.map((row) => row.id === customerId ? { ...row, status } : row));
      message.success(status === "ACTIVE" ? "账户已解冻" : status === "SUSPENDED" ? "账户已冻结" : "账户已禁用");
    } catch {
      message.error("账户状态更新未确认，请刷新核对最新状态后再操作");
    } finally {
      await loadCustomers();
      mutationLock.current = false;
      setSaving(false);
    }
  }

  useEffect(() => {
    const requests = listRequest;
    const initialLoad = window.setTimeout(() => { void loadCustomers(); }, 0);
    return () => { window.clearTimeout(initialLoad); requests.current++; };
  }, [loadCustomers]);

  const filtered = useMemo(() => {
    const value = keyword.trim().toLowerCase();
    if (!value) return customers;
    return customers.filter((item) =>
      [
        item.customerNo,
        item.fullName,
        item.phone,
        item.status,
        item.account?.accountNumber,
      ].some((field) => String(field ?? "").toLowerCase().includes(value)),
    );
  }, [customers, keyword]);

  const columns: ColumnsType<Customer> = [
    {
      title: "客户",
      key: "customer",
      width: 260,
      fixed: "left",
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.fullName || "未命名客户"}</Text>
          <Text type="secondary">{record.customerNo || "-"} / +91 {record.phone || "-"}</Text>
        </Space>
      ),
    },
    { title: "交易账号", key: "accountNumber", width: 180, render: (_, record) => record.account?.accountNumber || "-" },
    { title: "状态", dataIndex: "status", width: 120, render: statusTag },
    { title: "现金余额", key: "cash", width: 150, align: "right", render: (_, record) => formatMoney(record.account?.cashBalance) },
    { title: "可用资金", key: "buyingPower", width: 150, align: "right", render: (_, record) => formatMoney(record.account?.buyingPower) },
    { title: "冻结资金", key: "frozen", width: 150, align: "right", render: (_, record) => formatMoney(record.account?.frozenBalance) },
    {
      title: "操作",
      key: "actions",
      width: 260,
      fixed: "right",
      render: (_, record) => (
        <Space>
          <Button size="small" icon={<UnlockOutlined />} disabled={saving || loading || record.status === "ACTIVE"} onClick={() => updateStatus(record.id, "ACTIVE")}>
            解冻
          </Button>
          <Button size="small" icon={<LockOutlined />} disabled={saving || loading || record.status === "SUSPENDED"} onClick={() => updateStatus(record.id, "SUSPENDED")}>
            冻结
          </Button>
          <Popconfirm title="确认禁用该客户账户？" okText="确认" cancelText="取消" onConfirm={() => updateStatus(record.id, "DISABLED")}>
            <Button size="small" danger icon={<StopOutlined />} disabled={saving || loading || record.status === "DISABLED"}>
              禁用
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>账户管理</Title>
          <Paragraph type="secondary">查看自己名下客户账户，并对异常账户进行冻结、解冻或禁用。</Paragraph>
        </div>
        {error && <Alert type="error" title={error} showIcon />}
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input allowClear prefix={<SearchOutlined />} placeholder="搜索客户编号、姓名、手机号、交易账号或状态" value={keyword} onChange={(event) => setKeyword(event.target.value)} style={{ width: 430 }} />
            <Button icon={<ReloadOutlined />} disabled={saving} loading={loading} onClick={loadCustomers}>刷新</Button>
          </Space>
          <Table<Customer> rowKey="id" columns={columns} dataSource={filtered} loading={loading} scroll={{ x: 1280 }} pagination={{ pageSize: 20, showTotal: (total) => `共 ${total} 个账户` }} />
        </Card>
      </Space>
    </AdminShell>
  );
}
