"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Select, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from '@/lib/api';

const { Title, Paragraph, Text } = Typography;

type OrderRecord = {
  id: string;
  clientOrderId: string;
  side: string;
  type: string;
  status: string;
  quantity: number;
  filledQuantity: number;
  limitPrice?: string | null;
  averageFillPrice?: string | null;
  placedAt: string;
  completedAt?: string | null;
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
};

type OrdersResponse = {
  data: OrderRecord[];
  total: number;
  page: number;
  pageSize: number;
};

const sideLabels: Record<string, string> = {
  BUY: "买入",
  SELL: "卖出",
};

const statusLabels: Record<string, string> = {
  OPEN: "挂单中",
  PARTIALLY_FILLED: "部分成交",
  FILLED: "已成交",
  CANCELLED: "已撤单",
  REJECTED: "已拒绝",
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

export default function OrdersPage() {
  const [records, setRecords] = useState<OrderRecord[]>([]);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<string | undefined>();
  const [side, setSide] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const filtersRef = useRef({ search, status, side });
  useEffect(() => {
    filtersRef.current = { search, status, side };
  });

  const loadRecords = useCallback(async () => {
    const { search: nextSearch, status: nextStatus, side: nextSide } = filtersRef.current;
    setLoading(true);
    setError("");

    try {
      const response = await api.get<OrdersResponse>("/admin/orders", {
        params: {
          page: 1,
          pageSize: 100,
          search: nextSearch.trim() || undefined,
          status: nextStatus,
          side: nextSide,
        },
      });
      setRecords(Array.isArray(response.data.data) ? response.data.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "订单数据加载失败",
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadRecords();
  }, [loadRecords]);

  const columns: ColumnsType<OrderRecord> = [
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
      dataIndex: "side",
      width: 90,
      render: (value) => (
        <Tag color={value === "BUY" ? "green" : "red"}>{sideLabels[value] || value}</Tag>
      ),
    },
    { title: "类型", dataIndex: "type", width: 100 },
    {
      title: "状态",
      dataIndex: "status",
      width: 120,
      render: (value) => <Tag color={value === "FILLED" ? "blue" : "default"}>{statusLabels[value] || value}</Tag>,
    },
    { title: "数量", dataIndex: "quantity", width: 100, align: "right" },
    { title: "已成交", dataIndex: "filledQuantity", width: 100, align: "right" },
    {
      title: "成交均价",
      dataIndex: "averageFillPrice",
      width: 130,
      align: "right",
      render: formatMoney,
    },
    { title: "客户订单号", dataIndex: "clientOrderId", width: 230 },
    { title: "下单时间", dataIndex: "placedAt", width: 180, render: formatDate },
    { title: "完成时间", dataIndex: "completedAt", width: 180, render: formatDate },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>订单查询</Title>
          <Paragraph type="secondary">
            查看客户买入、卖出、撤单和成交状态，可按客户、手机号、交易账号或订单号查询。
          </Paragraph>
        </div>

        {error && <Alert type="error" showIcon title={error} />}

        <Card>
          <Space wrap>
            <Input
              allowClear
              prefix={<SearchOutlined />}
              placeholder="搜索客户、手机号、交易账号、订单号"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              onPressEnter={loadRecords}
              style={{ width: 320 }}
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
            <Select
              allowClear
              placeholder="状态"
              value={status}
              onChange={setStatus}
              style={{ width: 150 }}
              options={[
                { value: "OPEN", label: "挂单中" },
                { value: "PARTIALLY_FILLED", label: "部分成交" },
                { value: "FILLED", label: "已成交" },
                { value: "CANCELLED", label: "已撤单" },
                { value: "REJECTED", label: "已拒绝" },
              ]}
            />
            <Button type="primary" icon={<SearchOutlined />} loading={loading} onClick={loadRecords}>
              查询
            </Button>
            <Button icon={<ReloadOutlined />} loading={loading} onClick={loadRecords}>
              刷新
            </Button>
          </Space>

          <Table<OrderRecord>
            rowKey="id"
            columns={columns}
            dataSource={records}
            loading={loading}
            scroll={{ x: 1840 }}
            style={{ marginTop: 16 }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
