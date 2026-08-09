"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Select, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type TradeRecord = {
  id: string;
  executionId: string;
  quantity: number;
  price: string;
  grossAmount: string;
  feeAmount: string;
  netAmount: string;
  executedAt: string;
  account: {
    accountNumber: string;
    user: {
      customerNo?: string | null;
      fullName?: string | null;
      phone?: string | null;
    };
  };
  instrument: {
    exchange: string;
    symbol: string;
    name: string;
  };
  order: {
    clientOrderId: string;
    side: string;
    type: string;
    status: string;
  };
};

type TradesResponse = {
  data: TradeRecord[];
  total: number;
};

const sideLabels: Record<string, string> = {
  BUY: "买入",
  SELL: "卖出",
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export default function BusinessTradesPage() {
  const [records, setRecords] = useState<TradeRecord[]>([]);
  const [search, setSearch] = useState("");
  const [side, setSide] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadRecords() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<TradesResponse>("/business/my-trades", {
        params: {
          page: 1,
          pageSize: 100,
          search: search.trim() || undefined,
          side,
        },
      });
      setRecords(Array.isArray(response.data.data) ? response.data.data : []);
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "客户成交记录加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadRecords();
  }, []);

  const columns: ColumnsType<TradeRecord> = [
    {
      title: "客户",
      fixed: "left",
      width: 250,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.account.user.fullName || "未命名客户"}</Text>
          <Text type="secondary">
            {record.account.user.customerNo || "-"} / +91 {record.account.user.phone || "-"}
          </Text>
        </Space>
      ),
    },
    { title: "交易账号", width: 170, render: (_, record) => record.account.accountNumber },
    {
      title: "股票",
      width: 190,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.instrument.symbol}</Text>
          <Text type="secondary">{record.instrument.exchange} / {record.instrument.name}</Text>
        </Space>
      ),
    },
    {
      title: "方向",
      width: 90,
      render: (_, record) => (
        <Tag color={record.order.side === "BUY" ? "green" : "red"}>
          {sideLabels[record.order.side] || record.order.side}
        </Tag>
      ),
    },
    { title: "数量", dataIndex: "quantity", width: 100, align: "right" },
    { title: "成交价", dataIndex: "price", width: 130, align: "right", render: formatMoney },
    { title: "成交金额", dataIndex: "grossAmount", width: 140, align: "right", render: formatMoney },
    { title: "手续费", dataIndex: "feeAmount", width: 120, align: "right", render: formatMoney },
    { title: "净额", dataIndex: "netAmount", width: 140, align: "right", render: formatMoney },
    { title: "成交编号", dataIndex: "executionId", width: 220 },
    { title: "客户订单号", render: (_, record) => record.order.clientOrderId, width: 230 },
    { title: "成交时间", dataIndex: "executedAt", width: 180, render: formatDate },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>客户成交记录</Title>
          <Paragraph type="secondary">
            这里只显示自己名下客户的成交流水，便于查看客户实际买卖情况。
          </Paragraph>
        </div>

        {error && <Alert type="error" showIcon title={error} />}

        <Card>
          <Space wrap>
            <Input
              allowClear
              prefix={<SearchOutlined />}
              placeholder="搜索成交号、订单号、客户、手机号、交易账号、股票"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              onPressEnter={loadRecords}
              style={{ width: 390 }}
            />
            <Select
              allowClear
              placeholder="方向"
              value={side}
              onChange={setSide}
              style={{ width: 130 }}
              options={[
                { value: "BUY", label: "买入" },
                { value: "SELL", label: "卖出" },
              ]}
            />
            <Button type="primary" icon={<SearchOutlined />} loading={loading} onClick={loadRecords}>
              查询
            </Button>
            <Button icon={<ReloadOutlined />} loading={loading} onClick={loadRecords}>
              刷新
            </Button>
          </Space>

          <Table<TradeRecord>
            rowKey="id"
            columns={columns}
            dataSource={records}
            loading={loading}
            scroll={{ x: 1890 }}
            style={{ marginTop: 16 }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
