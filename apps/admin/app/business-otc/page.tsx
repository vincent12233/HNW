"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type OtcDeal = {
  id: string;
  orderNo: string;
  symbol: string;
  side: string;
  quantity: number;
  price: number;
  minTicket: number;
  status: string;
  note?: string | null;
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

export default function BusinessOtcPage() {
  const [items, setItems] = useState<OtcDeal[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadItems() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<OtcDeal[]>("/admin-products/block-trades");
      setItems(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(Array.isArray(responseMessage) ? responseMessage.join("，") : responseMessage || "OTC 机会加载失败");
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
    return items.filter((item) => [item.orderNo, item.symbol, item.side, item.status, item.note].some((field) => String(field ?? "").toLowerCase().includes(value)));
  }, [items, keyword]);

  const columns: ColumnsType<OtcDeal> = [
    { title: "编号", dataIndex: "orderNo", width: 170, render: (value) => <Text copyable>{value}</Text> },
    { title: "标的", dataIndex: "symbol", width: 140 },
    { title: "方向", dataIndex: "side", width: 100, render: (value) => <Tag color={value === "BUY" || value === "买入" ? "green" : "blue"}>{value}</Tag> },
    { title: "数量", dataIndex: "quantity", width: 120, align: "right" },
    { title: "价格", dataIndex: "price", width: 140, align: "right", render: formatMoney },
    { title: "最低参与", dataIndex: "minTicket", width: 140, align: "right", render: formatMoney },
    { title: "状态", dataIndex: "status", width: 120, render: (value) => <Tag color={value === "开放" ? "green" : "gold"}>{value}</Tag> },
    { title: "备注", dataIndex: "note", render: (value) => value || "-" },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>OTC</Title>
          <Paragraph type="secondary">这里对应原“大宗交易”模块，业务员可查看可跟进的大额 OTC 交易机会。</Paragraph>
        </div>
        {error && <Alert type="error" title={error} showIcon />}
        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input allowClear prefix={<SearchOutlined />} placeholder="搜索编号、标的、方向、状态或备注" value={keyword} onChange={(event) => setKeyword(event.target.value)} style={{ width: 420 }} />
            <Button icon={<ReloadOutlined />} onClick={loadItems} loading={loading}>刷新</Button>
          </Space>
          <Table<OtcDeal> rowKey="id" columns={columns} dataSource={filtered} loading={loading} scroll={{ x: 1180 }} pagination={{ pageSize: 15, showTotal: (total) => `共 ${total} 条 OTC 机会` }} />
        </Card>
      </Space>
    </AdminShell>
  );
}
