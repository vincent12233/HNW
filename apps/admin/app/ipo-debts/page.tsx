"use client";

import { ExclamationCircleOutlined, ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Col, Input, Row, Space, Statistic, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from '@/lib/api';

const { Title, Paragraph, Text } = Typography;

type IpoDebt = {
  id: string;
  amount: string;
  paidAmount: string;
  outstandingAmount: string;
  status: string;
  createdAt: string;
  updatedAt: string;
  account: {
    accountNumber: string;
    user: { customerNo?: string | null; fullName: string; phone?: string | null };
  };
  application: {
    id: string;
    allocatedQuantity?: number | null;
    allocatedPrice?: string | null;
    paymentStatus: string;
    status: string;
  };
  ipo: { symbol: string; companyName: string; issuePrice: string };
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 }).format(Number(value ?? 0));
}

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export default function IpoDebtsPage() {
  const [rows, setRows] = useState<IpoDebt[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadRows() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<IpoDebt[]>("/admin/ipo/debts");
      setRows(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "IPO 欠款加载失败");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadRows();
  }, []);

  const filteredRows = useMemo(() => {
    const query = keyword.trim().toLowerCase();
    if (!query) return rows;
    return rows.filter((row) => [row.account.accountNumber, row.account.user.customerNo, row.account.user.fullName, row.account.user.phone, row.ipo.symbol, row.ipo.companyName, row.status].some((value) => String(value ?? "").toLowerCase().includes(query)));
  }, [keyword, rows]);

  const totalOutstanding = filteredRows.reduce((sum, row) => sum + Number(row.outstandingAmount), 0);
  const overdueCount = filteredRows.filter((row) => row.status === "DEFAULTED").length;

  const columns: ColumnsType<IpoDebt> = [
    {
      title: "客户",
      width: 250,
      fixed: "left",
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{row.account.user.fullName || "未命名客户"}</Text>
          <Text type="secondary">{row.account.user.customerNo || "-"} / +91 {row.account.user.phone || "-"}</Text>
        </Space>
      ),
    },
    { title: "交易账号", width: 160, render: (_, row) => row.account.accountNumber },
    {
      title: "IPO",
      width: 240,
      render: (_, row) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{row.ipo.symbol}</Text>
          <Text type="secondary">{row.ipo.companyName}</Text>
        </Space>
      ),
    },
    { title: "中签数量", width: 120, render: (_, row) => row.application.allocatedQuantity ? `${row.application.allocatedQuantity} 股` : "-" },
    { title: "已付金额", dataIndex: "paidAmount", width: 140, align: "right", render: formatMoney },
    { title: "欠款金额", dataIndex: "outstandingAmount", width: 140, align: "right", render: (value) => <Text type={Number(value) > 0 ? "danger" : undefined}>{formatMoney(value)}</Text> },
    { title: "付款状态", width: 120, render: (_, row) => <Tag color={row.application.paymentStatus === "PAID" ? "green" : "orange"}>{row.application.paymentStatus}</Tag> },
    { title: "欠款状态", dataIndex: "status", width: 120, render: (value) => <Tag color={value === "PAID" ? "green" : value === "DEFAULTED" ? "red" : "orange"}>{value}</Tag> },
    { title: "更新时间", dataIndex: "updatedAt", width: 180, render: formatDate },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>IPO 欠款</Title>
          <Paragraph type="secondary">显示 IPO 分配后未补足的真实欠款。客户补款由财务上分自动抵扣，补足后系统自动转入持仓。</Paragraph>
        </div>
        {error && <Alert type="error" title={error} showIcon />}
        <Row gutter={[16, 16]}>
          <Col xs={24} md={8}><Card><Statistic title="欠款总额" value={formatMoney(totalOutstanding)} /></Card></Col>
          <Col xs={24} md={8}><Card><Statistic title="待跟进订单" value={filteredRows.filter((row) => row.status !== "PAID").length} /></Card></Col>
          <Col xs={24} md={8}><Card><Statistic title="逾期订单" value={overdueCount} prefix={<ExclamationCircleOutlined />} /></Card></Col>
        </Row>
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input prefix={<SearchOutlined />} allowClear placeholder="搜索客户、手机号、交易账号或 IPO" value={keyword} onChange={(event) => setKeyword(event.target.value)} style={{ width: 380 }} />
            <Button icon={<ReloadOutlined />} onClick={loadRows} loading={loading}>刷新</Button>
          </Space>
          <Table<IpoDebt> rowKey="id" dataSource={filteredRows} columns={columns} loading={loading} scroll={{ x: 1480 }} pagination={{ pageSize: 15, showTotal: (total) => `共 ${total} 条欠款记录` }} />
        </Card>
      </Space>
    </AdminShell>
  );
}
