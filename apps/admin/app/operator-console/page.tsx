"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Input, Space, Table, Tag, Typography } from "antd";
import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/components/AdminShell";
import ScopedEditButton from "@/components/ScopedEditButton";
import { api } from "@/lib/api";

type Customer = {
  id: string;
  customerNo?: string | null;
  fullName: string;
  phone?: string | null;
  status: string;
  createdAt: string;
  usedInviteCode?: { code: string; usedAt?: string | null } | null;
  account?: { accountNumber: string; cashBalance: string | number; buyingPower: string | number; frozenBalance: string | number; currency: string; isLive: boolean } | null;
};

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

  useEffect(() => { void load(); }, []);

  const filtered = useMemo(() => {
    const value = keyword.trim().toLowerCase();
    if (!value) return rows;
    return rows.filter((row) => [row.fullName, row.phone, row.customerNo, row.account?.accountNumber, row.usedInviteCode?.code].some((item) => String(item || "").toLowerCase().includes(value)));
  }, [keyword, rows]);

  return <AdminShell>
    <Space orientation="vertical" size="large" style={{ width: "100%" }}>
      <div>
        <Typography.Title level={2}>固定邀请码客户</Typography.Title>
        <Typography.Paragraph type="secondary">这里只显示使用超级管理员固定邀请码注册的客户，普通业务员邀请码客户不会出现在此处。</Typography.Paragraph>
      </div>
      {error && <Alert type="error" title={error} showIcon />}
      <Space wrap>
        <Input prefix={<SearchOutlined />} placeholder="姓名、手机号、客户号或账户号" value={keyword} onChange={(event) => setKeyword(event.target.value)} allowClear style={{ width: 300 }} />
        <Button icon={<ReloadOutlined />} onClick={() => void load()} loading={loading}>刷新</Button>
        <Tag color="blue">专用运营员范围：{rows.length} 个客户</Tag>
      </Space>
      <Table<Customer> rowKey="id" loading={loading} dataSource={filtered} scroll={{ x: 1000 }} columns={[
        { title: "客户姓名", dataIndex: "fullName" },
        { title: "操作", fixed: "right", width: 160, render: (_, row) =>
          <ScopedEditButton name={row.fullName} current={row.status} kind="status"
            endpoint={`/business/customers/${row.id}/status`} onSaved={load} /> },
        { title: "手机号", dataIndex: "phone", render: (value) => value || "-" },
        { title: "内部用户号", dataIndex: "customerNo", render: (value) => value || "-" },
        { title: "账户号", render: (_, row) => row.account?.accountNumber || "-" },
        { title: "固定邀请码", render: (_, row) => row.usedInviteCode?.code || "-" },
        { title: "现金余额", render: (_, row) => `${row.account?.currency || "INR"} ${Number(row.account?.cashBalance || 0).toFixed(2)}` },
        { title: "状态", render: (_, row) => <Tag color={row.status === "ACTIVE" ? "green" : "orange"}>{row.status === "ACTIVE" ? "正常" : row.status}</Tag> },
      ]} />
    </Space>
  </AdminShell>;
}
