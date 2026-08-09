"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Modal, Space, Table, Tag, Typography, message } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type IpoApplication = {
  id: string;
  status: string;
  paymentStatus: string;
  allocatedQuantity?: number | null;
  allocatedPrice?: string | null;
  allocatedAmount?: string | null;
  createdAt: string;
  ipo: { symbol: string; companyName: string; issuePrice: string; status: string };
  account: {
    accountNumber: string;
    cashBalance: string;
    user: { customerNo?: string | null; fullName: string; phone?: string | null; status: string };
  };
  debt?: { amount: string; paidAmount: string; status: string } | null;
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 }).format(Number(value ?? 0));
}

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export default function BusinessIpoPage() {
  const [items, setItems] = useState<IpoApplication[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadItems() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<IpoApplication[]>("/business/my-ipo-applications");
      setItems(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(Array.isArray(responseMessage) ? responseMessage.join("，") : responseMessage || "IPO 申请加载失败");
    } finally {
      setLoading(false);
    }
  }

  async function allocate(record: IpoApplication) {
    let quantity = "";
    let price = record.ipo.issuePrice;

    Modal.confirm({
      title: "分配 IPO",
      content: (
        <Space orientation="vertical" style={{ width: "100%" }}>
          <Text>{record.ipo.symbol} / {record.ipo.companyName}</Text>
          <Text type="secondary">客户现金：{formatMoney(record.account.cashBalance)}。不足部分会自动生成欠款，未补足不会转入持仓。</Text>
          <Input placeholder="分配数量" onChange={(event) => { quantity = event.target.value; }} />
          <Input placeholder="分配价格" defaultValue={price} onChange={(event) => { price = event.target.value; }} />
        </Space>
      ),
      okText: "确认分配",
      cancelText: "取消",
      async onOk() {
        await api.patch(`/business/my-ipo-applications/${record.id}/allocate`, {
          quantity: Number(quantity),
          price: Number(price),
        });
        message.success("IPO 已分配，系统已按规则扣款或生成欠款");
        await loadItems();
      },
    });
  }

  useEffect(() => {
    loadItems();
  }, []);

  const filtered = useMemo(() => {
    const value = keyword.trim().toLowerCase();
    if (!value) return items;
    return items.filter((item) => [item.ipo.symbol, item.ipo.companyName, item.account.accountNumber, item.account.user.customerNo, item.account.user.fullName, item.account.user.phone, item.status, item.paymentStatus].some((field) => String(field ?? "").toLowerCase().includes(value)));
  }, [items, keyword]);

  const columns: ColumnsType<IpoApplication> = [
    {
      title: "客户",
      key: "customer",
      width: 240,
      fixed: "left",
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.account.user.fullName || "未命名客户"}</Text>
          <Text type="secondary">{record.account.user.customerNo || "-"} / +91 {record.account.user.phone || "-"}</Text>
        </Space>
      ),
    },
    { title: "交易账号", key: "account", width: 160, render: (_, record) => record.account.accountNumber },
    { title: "IPO", key: "ipo", width: 230, render: (_, record) => <Space orientation="vertical" size={0}><Text strong>{record.ipo.symbol}</Text><Text type="secondary">{record.ipo.companyName}</Text></Space> },
    { title: "发行价", key: "issuePrice", width: 120, align: "right", render: (_, record) => formatMoney(record.ipo.issuePrice) },
    { title: "申请状态", dataIndex: "status", width: 120, render: (value) => <Tag color={value === "PENDING" ? "orange" : "blue"}>{value}</Tag> },
    { title: "付款状态", dataIndex: "paymentStatus", width: 120, render: (value) => <Tag color={value === "PAID" ? "green" : "orange"}>{value}</Tag> },
    { title: "已分配", dataIndex: "allocatedQuantity", width: 120, render: (value) => value ? `${value} 股` : "-" },
    { title: "欠款", key: "debt", width: 130, align: "right", render: (_, record) => record.debt ? formatMoney(Number(record.debt.amount) - Number(record.debt.paidAmount)) : "-" },
    { title: "申请时间", dataIndex: "createdAt", width: 180, render: formatDate },
    {
      title: "操作",
      key: "actions",
      width: 130,
      fixed: "right",
      render: (_, record) => <Button type="primary" size="small" disabled={record.status !== "PENDING"} onClick={() => allocate(record)}>分配</Button>,
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>IPO 分配</Title>
          <Paragraph type="secondary">客户提交 IPO 申请后无需填写数量，由业务员在这里分配。系统自动扣款，不足部分生成欠款，补足后自动进入持仓。</Paragraph>
        </div>
        {error && <Alert type="error" title={error} showIcon />}
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input allowClear prefix={<SearchOutlined />} placeholder="搜索客户、手机号、交易账号或 IPO" value={keyword} onChange={(event) => setKeyword(event.target.value)} style={{ width: 420 }} />
            <Button icon={<ReloadOutlined />} onClick={loadItems} loading={loading}>刷新</Button>
          </Space>
          <Table<IpoApplication> rowKey="id" columns={columns} dataSource={filtered} loading={loading} scroll={{ x: 1560 }} pagination={{ pageSize: 15, showTotal: (total) => `共 ${total} 条 IPO 申请` }} />
        </Card>
      </Space>
    </AdminShell>
  );
}
