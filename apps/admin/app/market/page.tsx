"use client";

import {
  EditOutlined,
  PlusOutlined,
  ReloadOutlined,
  SearchOutlined,
  StockOutlined,
  ThunderboltOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Form,
  Input,
  InputNumber,
  Modal,
  Select,
  Space,
  Switch,
  Table,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from '@/lib/api';

const { Title, Paragraph, Text } = Typography;

type Instrument = {
  id: string;
  exchange: string;
  symbol: string;
  name: string;
  isin?: string | null;
  logoUrl?: string | null;
  category?: string | null;
  displayOrder: number;
  type: string;
  currency: string;
  lotSize: number;
  tickSize: string | number;
  isActive: boolean;
  quote?: {
    lastPrice: string | number;
    bidPrice?: string | number | null;
    askPrice?: string | number | null;
    volume?: string | number | null;
    asOf?: string | null;
  } | null;
  statistics?: {
    orderCount: number;
    tradeCount: number;
    positionCount: number;
  };
};

type InstrumentResponse = {
  data: Instrument[];
  total: number;
  page: number;
  pageSize: number;
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

export default function MarketAdminPage() {
  const [items, setItems] = useState<Instrument[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [createOpen, setCreateOpen] = useState(false);
  const [quoteOpen, setQuoteOpen] = useState(false);
  const [selected, setSelected] = useState<Instrument | null>(null);
  const [createForm] = Form.useForm();
  const [quoteForm] = Form.useForm();

  async function loadItems() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<InstrumentResponse>("/admin/market/instruments", {
        params: {
          search: keyword || undefined,
          pageSize: 100,
        },
      });
      setItems(Array.isArray(response.data.data) ? response.data.data : []);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "股票加载失败"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadItems();
  }, []);

  const filtered = useMemo(() => items, [items]);

  async function createInstrument() {
    const values = await createForm.validateFields();

    try {
      await api.post("/admin/market/instruments", {
        ...values,
        symbol: values.symbol.trim().toUpperCase(),
        currency: "INR",
        lotSize: Number(values.lotSize ?? 1),
        volume: Number(values.volume ?? 0),
        tickSize: String(values.tickSize),
        lastPrice: String(values.lastPrice),
        bidPrice: values.bidPrice ? String(values.bidPrice) : undefined,
        askPrice: values.askPrice ? String(values.askPrice) : undefined,
        logoUrl: values.logoUrl?.trim() || undefined,
        category: values.category?.trim() || undefined,
        displayOrder: Number(values.displayOrder ?? 0),
      });
      message.success("股票已添加");
      setCreateOpen(false);
      createForm.resetFields();
      await loadItems();
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "股票添加失败"));
    }
  }

  async function updateStatus(record: Instrument, isActive: boolean) {
    try {
      await api.patch(`/admin/market/instruments/${record.id}/status`, {
        isActive,
      });
      message.success(isActive ? "股票已启用" : "股票已停用");
      await loadItems();
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "状态更新失败"));
    }
  }

  function openQuote(record: Instrument) {
    setSelected(record);
    quoteForm.setFieldsValue({
      lastPrice: Number(record.quote?.lastPrice ?? 0),
      bidPrice: Number(record.quote?.bidPrice ?? record.quote?.lastPrice ?? 0),
      askPrice: Number(record.quote?.askPrice ?? record.quote?.lastPrice ?? 0),
      volume: Number(record.quote?.volume ?? 0),
    });
    setQuoteOpen(true);
  }

  async function updateQuote() {
    if (!selected) return;
    const values = await quoteForm.validateFields();

    try {
      await api.patch(
        `/admin/market/quotes/${selected.exchange}/${selected.symbol}`,
        {
          lastPrice: Number(values.lastPrice).toFixed(4),
          bidPrice: Number(values.bidPrice || values.lastPrice).toFixed(4),
          askPrice: Number(values.askPrice || values.lastPrice).toFixed(4),
          volume: Number(values.volume ?? 0),
        },
      );
      message.success("行情价格已更新");
      setQuoteOpen(false);
      setSelected(null);
      await loadItems();
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "行情更新失败"));
    }
  }

  async function seedMarket() {
    try {
      await api.post("/admin/market/seed");
      message.success("示例行情已初始化");
      await loadItems();
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "初始化失败"));
    }
  }

  const columns: ColumnsType<Instrument> = [
    {
      title: "代码",
      dataIndex: "symbol",
      width: 190,
      fixed: "left",
      render: (value, record) => (
        <Space>
          <span
            style={{
              width: 34,
              height: 34,
              borderRadius: "50%",
              display: "inline-flex",
              alignItems: "center",
              justifyContent: "center",
              overflow: "hidden",
              background: "#eef4ff",
              border: "1px solid #dbe7f7",
            }}
          >
            {record.logoUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={record.logoUrl} alt={value} style={{ width: 30, height: 30, borderRadius: "50%", objectFit: "cover" }} />
            ) : (
              <StockOutlined style={{ color: "#2563eb" }} />
            )}
          </span>
          <Space orientation="vertical" size={0}>
            <Text strong>{value}</Text>
            <Text type="secondary">{record.exchange}</Text>
          </Space>
        </Space>
      ),
    },
    { title: "名称", dataIndex: "name", width: 220 },
    { title: "分类", dataIndex: "category", width: 130, render: (value) => value || "-" },
    { title: "排序", dataIndex: "displayOrder", width: 90, align: "right" },
    { title: "类型", dataIndex: "type", width: 110 },
    {
      title: "最新价",
      width: 130,
      align: "right",
      render: (_, record) => formatMoney(record.quote?.lastPrice),
    },
    {
      title: "买价/卖价",
      width: 170,
      render: (_, record) => (
        <Text>
          {formatMoney(record.quote?.bidPrice)} / {formatMoney(record.quote?.askPrice)}
        </Text>
      ),
    },
    {
      title: "成交量",
      width: 120,
      align: "right",
      render: (_, record) => Number(record.quote?.volume ?? 0).toLocaleString("en-IN"),
    },
    {
      title: "状态",
      dataIndex: "isActive",
      width: 110,
      render: (value: boolean, record) => (
        <Switch
          checked={value}
          checkedChildren="启用"
          unCheckedChildren="停用"
          onChange={(checked) => updateStatus(record, checked)}
        />
      ),
    },
    {
      title: "订单/持仓",
      width: 140,
      render: (_, record) => (
        <Text type="secondary">
          {record.statistics?.orderCount ?? 0} / {record.statistics?.positionCount ?? 0}
        </Text>
      ),
    },
    {
      title: "操作",
      width: 120,
      fixed: "right",
      render: (_, record) => (
        <Button icon={<EditOutlined />} onClick={() => openQuote(record)}>
          改价
        </Button>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>股票管理</Title>
          <Paragraph type="secondary">
            管理客户 App 可交易股票、指数和行情价格。新增股票后，启用状态下会进入客户行情和交易列表。
          </Paragraph>
        </div>

        {error && <Alert type="error" title={error} showIcon />}

        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Space wrap>
              <Input
                allowClear
                prefix={<SearchOutlined />}
                placeholder="搜索代码、名称或 ISIN"
                value={keyword}
                onChange={(event) => setKeyword(event.target.value)}
                onPressEnter={loadItems}
                style={{ width: 320 }}
              />
              <Button icon={<ReloadOutlined />} onClick={loadItems} loading={loading}>
                刷新
              </Button>
            </Space>

            <Space>
              <Button icon={<ThunderboltOutlined />} onClick={seedMarket}>
                初始化示例
              </Button>
              <Button type="primary" icon={<PlusOutlined />} onClick={() => setCreateOpen(true)}>
                添加股票
              </Button>
            </Space>
          </Space>

          <Table
            rowKey="id"
            columns={columns}
            dataSource={filtered}
            loading={loading}
            scroll={{ x: 1300 }}
            pagination={{
              pageSize: 20,
              showSizeChanger: true,
              showTotal: (total) => `共 ${total} 只股票`,
            }}
          />
        </Card>
      </Space>

      <Modal
        title="添加股票"
        open={createOpen}
        onCancel={() => setCreateOpen(false)}
        onOk={createInstrument}
        okText="保存"
        cancelText="取消"
        width={720}
      >
        <Form
          form={createForm}
          layout="vertical"
          initialValues={{
            exchange: "NSE",
            type: "EQUITY",
            lotSize: 1,
            tickSize: "0.05",
            currency: "INR",
            volume: 0,
            displayOrder: 0,
          }}
        >
          <Space align="start" style={{ width: "100%" }}>
            <Form.Item name="exchange" label="交易所" rules={[{ required: true }]}>
              <Select style={{ width: 160 }} options={[{ value: "NSE" }, { value: "BSE" }]} />
            </Form.Item>
            <Form.Item name="type" label="类型" rules={[{ required: true }]}>
              <Select
                style={{ width: 160 }}
                options={[
                  { value: "EQUITY", label: "股票" },
                  { value: "ETF", label: "ETF" },
                  { value: "INDEX", label: "指数" },
                ]}
              />
            </Form.Item>
            <Form.Item name="symbol" label="代码" rules={[{ required: true, message: "请输入代码" }]}>
              <Input style={{ width: 180 }} placeholder="例如 INFY" />
            </Form.Item>
          </Space>
          <Form.Item name="name" label="名称" rules={[{ required: true, message: "请输入名称" }]}>
            <Input placeholder="例如 Infosys Limited" />
          </Form.Item>
          <Form.Item name="isin" label="ISIN">
            <Input placeholder="可选" />
          </Form.Item>
          <Form.Item name="logoUrl" label="公司 Logo URL">
            <Input placeholder="请使用公司授权的 HTTPS Logo 地址" />
          </Form.Item>
          <Space align="start" style={{ width: "100%" }}>
            <Form.Item name="category" label="分类">
              <Input style={{ width: 220 }} placeholder="例如 Bank / IT / Energy" />
            </Form.Item>
            <Form.Item name="displayOrder" label="显示排序">
              <InputNumber min={0} style={{ width: 160 }} />
            </Form.Item>
          </Space>
          <Space align="start" style={{ width: "100%" }}>
            <Form.Item name="lotSize" label="每手数量">
              <InputNumber min={1} style={{ width: 150 }} />
            </Form.Item>
            <Form.Item name="tickSize" label="最小跳动" rules={[{ required: true }]}>
              <Input style={{ width: 150 }} />
            </Form.Item>
            <Form.Item name="lastPrice" label="最新价" rules={[{ required: true, message: "请输入价格" }]}>
              <InputNumber min={0.01} precision={2} style={{ width: 150 }} />
            </Form.Item>
            <Form.Item name="volume" label="成交量">
              <InputNumber min={0} style={{ width: 150 }} />
            </Form.Item>
          </Space>
        </Form>
      </Modal>

      <Modal
        title={selected ? `${selected.symbol} - 修改行情` : "修改行情"}
        open={quoteOpen}
        onCancel={() => setQuoteOpen(false)}
        onOk={updateQuote}
        okText="保存"
        cancelText="取消"
      >
        <Form form={quoteForm} layout="vertical">
          <Form.Item name="lastPrice" label="最新价" rules={[{ required: true }]}>
            <InputNumber min={0.01} precision={2} style={{ width: "100%" }} />
          </Form.Item>
          <Form.Item name="bidPrice" label="买价">
            <InputNumber min={0.01} precision={2} style={{ width: "100%" }} />
          </Form.Item>
          <Form.Item name="askPrice" label="卖价">
            <InputNumber min={0.01} precision={2} style={{ width: "100%" }} />
          </Form.Item>
          <Form.Item name="volume" label="成交量">
            <InputNumber min={0} style={{ width: "100%" }} />
          </Form.Item>
        </Form>
      </Modal>
    </AdminShell>
  );
}
