"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api } from "@/lib/api";

const { Text } = Typography;

type BankAccount = {
  id: string;
  bankName: string;
  accountHolder: string;
  accountNumber: string;
  ifscCode: string;
  isPrimary: boolean;
  createdAt: string;
  user: { fullName: string; phone?: string; customerNo?: string };
};

export default function BankAccountsPage() {
  const [rows, setRows] = useState<BankAccount[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<BankAccount[]>("/admin/bank-accounts");
      setRows(Array.isArray(response.data) ? response.data : []);
    } catch (e: any) {
      setError(e.response?.data?.message || "银行账户加载失败");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  const data = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter((row) =>
      [row.bankName, row.accountHolder, row.accountNumber, row.ifscCode, row.user.fullName, row.user.phone, row.user.customerNo]
        .some((value) => String(value ?? "").toLowerCase().includes(q)),
    );
  }, [query, rows]);

  const primaryCount = useMemo(() => rows.filter((row) => row.isPrimary).length, [rows]);

  const columns: ColumnsType<BankAccount> = [
    {
      title: "客户",
      width: 220,
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{row.user.fullName}</Text>
          <Text type="secondary">
            {row.user.customerNo || "-"} / +91 {row.user.phone || "-"}
          </Text>
        </Space>
      ),
    },
    { title: "开户名", dataIndex: "accountHolder", width: 160 },
    { title: "银行", dataIndex: "bankName", width: 160 },
    {
      title: "账户",
      dataIndex: "accountNumber",
      width: 180,
      render: (value) => <Text copyable>{value}</Text>,
    },
    { title: "IFSC", dataIndex: "ifscCode", width: 130 },
    {
      title: "状态",
      width: 110,
      render: (_, row) => <Tag color={row.isPrimary ? "green" : "default"}>{row.isPrimary ? "主要账户" : "已添加"}</Tag>,
    },
    {
      title: "添加时间",
      dataIndex: "createdAt",
      width: 180,
      render: (value) => new Date(value).toLocaleString("zh-CN"),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          eyebrow="SETTLEMENT"
          title="客户银行账户"
          description="客户在 APP 添加后立即同步显示，本页只读查看，无需审核，也不改变提现收款校验流程。"
          extra={
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => void load()}>
              刷新
            </Button>
          }
        />

        <div className="ops-stat-strip">
          <div className="ops-stat-pill">
            <span className="label">账户总数</span>
            <span className="value">{rows.length}</span>
          </div>
          <div className="ops-stat-pill">
            <span className="label">主要账户</span>
            <span className="value">{primaryCount}</span>
          </div>
          <div className="ops-stat-pill">
            <span className="label">当前筛选</span>
            <span className="value">{data.length}</span>
          </div>
        </div>

        {error && <Alert type="error" showIcon title={error} action={<Button onClick={() => void load()}>重试</Button>} />}

        <Card>
          <div className="ops-toolbar">
            <Input
              allowClear
              prefix={<SearchOutlined />}
              placeholder="搜索客户、银行、账号或 IFSC"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              style={{ width: 380, maxWidth: "100%" }}
            />
          </div>
          <Table
            rowKey="id"
            columns={columns}
            dataSource={data}
            loading={loading}
            scroll={{ x: 1140 }}
            pagination={{ pageSize: 20, showTotal: (total) => `共 ${total} 个银行账户` }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
