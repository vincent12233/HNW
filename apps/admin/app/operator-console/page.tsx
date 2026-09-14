"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";
import ScopedEditButton from "@/components/ScopedEditButton";
import { api } from "@/lib/api";

const { Text } = Typography;

type Customer = {
  id: string;
  customerNo?: string | null;
  fullName: string;
  phone?: string | null;
  status: string;
  createdAt: string;
  usedInviteCode?: { code: string; usedAt?: string | null } | null;
  account?: {
    accountNumber: string;
    cashBalance: string | number;
    buyingPower: string | number;
    frozenBalance: string | number;
    currency: string;
    isLive: boolean;
  } | null;
};

function money(currency: string | undefined, value: string | number | undefined) {
  return `${currency || "INR"} ${Number(value || 0).toLocaleString("en-IN", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

export default function OperatorConsolePage() {
  const [rows, setRows] = useState<Customer[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get<Customer[]>("/operator/customers");
      setRows(Array.isArray(data) ? data : []);
    } catch (requestError: any) {
      setError(requestError.response?.data?.message || "专用运营员客户数据加载失败");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  const filtered = useMemo(() => {
    const value = keyword.trim().toLowerCase();
    if (!value) return rows;
    return rows.filter((row) =>
      [row.fullName, row.phone, row.customerNo, row.account?.accountNumber, row.usedInviteCode?.code].some((item) =>
        String(item || "").toLowerCase().includes(value),
      ),
    );
  }, [keyword, rows]);

  const activeCount = useMemo(() => rows.filter((row) => row.status === "ACTIVE").length, [rows]);

  const columns: ColumnsType<Customer> = [
    {
      title: "客户",
      width: 200,
      fixed: "left",
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{row.fullName}</Text>
          <Text type="secondary">{row.customerNo || "-"}</Text>
        </Space>
      ),
    },
    {
      title: "手机号",
      dataIndex: "phone",
      width: 140,
      render: (value) => (value ? `+91 ${value}` : "-"),
    },
    {
      title: "交易账号",
      width: 160,
      render: (_, row) => row.account?.accountNumber || "-",
    },
    {
      title: "固定邀请码",
      width: 140,
      render: (_, row) => row.usedInviteCode?.code || "-",
    },
    {
      title: "现金余额",
      width: 150,
      align: "right",
      render: (_, row) => money(row.account?.currency, row.account?.cashBalance),
    },
    {
      title: "可用资金",
      width: 150,
      align: "right",
      render: (_, row) => money(row.account?.currency, row.account?.buyingPower),
    },
    {
      title: "状态",
      width: 100,
      render: (_, row) => (
        <Tag color={row.status === "ACTIVE" ? "green" : "orange"}>
          {row.status === "ACTIVE" ? "正常" : row.status}
        </Tag>
      ),
    },
    {
      title: "注册时间",
      dataIndex: "createdAt",
      width: 180,
      render: (value) => new Date(value).toLocaleString("zh-CN"),
    },
    {
      title: "操作",
      fixed: "right",
      width: 160,
      render: (_, row) => (
        <ScopedEditButton
          name={row.fullName}
          current={row.status}
          kind="status"
          endpoint={`/business/customers/${row.id}/status`}
          onSaved={load}
        />
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          eyebrow="SUPPORT SCOPE"
          title="固定邀请码客户"
          description="仅显示使用超级管理员固定邀请码注册的客户。普通业务员邀请码客户不会出现在此页，权限范围保持隔离。"
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()}>
              刷新
            </Button>
          }
        />

        <div className="ops-stat-strip">
          <div className="ops-stat-pill">
            <span className="label">专用范围客户</span>
            <span className="value">{rows.length}</span>
          </div>
          <div className="ops-stat-pill">
            <span className="label">正常状态</span>
            <span className="value">{activeCount}</span>
          </div>
          <div className="ops-stat-pill">
            <span className="label">当前筛选</span>
            <span className="value">{filtered.length}</span>
          </div>
        </div>

        {error && (
          <Alert type="error" showIcon title={error} action={<Button onClick={() => void load()}>重试</Button>} />
        )}

        <Card>
          <div className="ops-toolbar">
            <Input
              allowClear
              prefix={<SearchOutlined />}
              placeholder="姓名、手机号、客户号、账户号或邀请码"
              value={keyword}
              onChange={(event) => setKeyword(event.target.value)}
              style={{ width: 360, maxWidth: "100%" }}
            />
            <Tag color="blue">专用运营员范围</Tag>
          </div>
          <Table
            rowKey="id"
            loading={loading}
            dataSource={filtered}
            columns={columns}
            scroll={{ x: 1400 }}
            pagination={{ pageSize: 20, showTotal: (total) => `共 ${total} 位客户` }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
