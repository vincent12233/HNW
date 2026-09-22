"use client";

import { LockOutlined, ReloadOutlined, SearchOutlined, StopOutlined, UnlockOutlined } from "@ant-design/icons";
import { Button, Card, Input, Popconfirm, Space, Table, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { isAxiosError } from "axios";

import AdminShell from "@/components/AdminShell";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import { api } from "@/lib/api";
import { filterLoadedRows, maskOpsPhone } from "@/lib/ops-directory";

const { Text } = Typography;

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
  return <OpsStatusTag code={status} />;
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
    return filterLoadedRows(customers, keyword, (item) => [
      item.customerNo,
      item.fullName,
      maskOpsPhone(item.phone, ""),
      item.status,
      item.account?.accountNumber,
    ]);
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
          <Text type="secondary">{record.customerNo || "Unavailable"} / {maskOpsPhone(record.phone)}</Text>
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
          <Button size="small" icon={<UnlockOutlined />} aria-label="解冻账户" disabled={saving || loading || record.status === "ACTIVE"} onClick={() => updateStatus(record.id, "ACTIVE")}>
            解冻
          </Button>
          <Button size="small" icon={<LockOutlined />} aria-label="冻结账户" disabled={saving || loading || record.status === "SUSPENDED"} onClick={() => updateStatus(record.id, "SUSPENDED")}>
            冻结
          </Button>
          <Popconfirm title="确认禁用该客户账户？" okText="确认" cancelText="取消" onConfirm={() => updateStatus(record.id, "DISABLED")}>
            <Button size="small" danger icon={<StopOutlined />} aria-label="禁用账户" disabled={saving || loading || record.status === "DISABLED"}>
              禁用
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title="账户管理"
          crumbs={[{ title: "我的客户" }, { title: "账户管理" }]}
          description="查看自己名下客户账户，并对异常账户进行冻结、解冻或禁用。列表手机号已脱敏。本页不新增资金或交易操作。"
          extra={<Button icon={<ReloadOutlined />} disabled={saving} loading={loading} onClick={() => void loadCustomers()} aria-label="刷新客户账户">刷新</Button>}
        />
        {error ? <OpsErrorState title={error} onRetry={() => void loadCustomers()} /> : null}
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input allowClear prefix={<SearchOutlined />} placeholder="搜索已加载的客户编号、姓名、脱敏手机号、交易账号或状态" value={keyword} onChange={(event) => setKeyword(event.target.value)} aria-label="搜索已加载账户" style={{ width: 430, maxWidth: "100%" }} />
          </Space>
          <Table<Customer> rowKey="id" className="ops-directory-table" columns={columns} dataSource={filtered} loading={loading} scroll={{ x: 1280 }} pagination={{ pageSize: 20, showTotal: (total) => `共 ${total} 个已加载账户` }} locale={{ emptyText: <OpsEmpty description={loading ? "正在加载账户" : "当前没有已加载的客户账户。"} onRetry={loading ? undefined : () => void loadCustomers()} /> }} />
        </Card>
      </Space>
    </AdminShell>
  );
}
