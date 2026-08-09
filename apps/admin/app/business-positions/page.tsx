"use client";

import {
  HomeOutlined,
  ReloadOutlined,
  SearchOutlined,
  WalletOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Col,
  Input,
  Row,
  Space,
  Statistic,
  Table,
  Tabs,
  Tag,
  Typography,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type PositionCategory = "INSTITUTIONAL" | "IPO" | "OTC";

type BusinessPosition = {
  id: string;
  category: PositionCategory;
  account: {
    accountNumber: string;
    currency: string;
    user: {
      customerNo?: string | null;
      fullName?: string | null;
      phone?: string | null;
      status: string;
    };
  };
  instrument: {
    exchange: string;
    symbol: string;
    name: string;
    category?: string | null;
  };
  quantity: number;
  frozenQuantity: number;
  availableQuantity: number;
  averagePrice: string;
  lastPrice: string;
  marketValue: string;
  unrealizedPnl: string;
  realizedPnl: string;
  updatedAt: string;
};

type PositionsResponse = {
  summary: {
    count: number;
    quantity: number;
    marketValue: string;
    unrealizedPnl: string;
    categories: Record<PositionCategory, number>;
  };
  data: BusinessPosition[];
};

const categoryLabels: Record<PositionCategory, string> = {
  INSTITUTIONAL: "涨停股",
  IPO: "IPO",
  OTC: "OTC",
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

export default function BusinessPositionsPage() {
  const [positions, setPositions] = useState<BusinessPosition[]>([]);
  const [summary, setSummary] = useState<PositionsResponse["summary"] | null>(
    null,
  );
  const [category, setCategory] = useState<PositionCategory>("INSTITUTIONAL");
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadPositions(nextCategory = category) {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<PositionsResponse>("/business/my-positions", {
        params: {
          category: nextCategory,
          search: keyword.trim() || undefined,
        },
      });

      setSummary(response.data.summary);
      setPositions(Array.isArray(response.data.data) ? response.data.data : []);
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "持仓数据加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadPositions(category);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [category]);

  const totalPnl = Number(summary?.unrealizedPnl ?? 0);

  const columns: ColumnsType<BusinessPosition> = useMemo(
    () => [
      {
        title: "客户",
        key: "customer",
        width: 250,
        render: (_, record) => (
          <Space orientation="vertical" size={0}>
            <Text strong>{record.account.user.fullName || "未命名客户"}</Text>
            <Text type="secondary">
              {record.account.user.customerNo || "-"} / +91{" "}
              {record.account.user.phone || "-"}
            </Text>
            <Text type="secondary">{record.account.accountNumber}</Text>
          </Space>
        ),
      },
      {
        title: "持仓标的",
        key: "instrument",
        width: 240,
        render: (_, record) => (
          <Space orientation="vertical" size={0}>
            <Space>
              <Tag color="blue">{record.instrument.exchange}</Tag>
              <Text strong>{record.instrument.symbol}</Text>
            </Space>
            <Text type="secondary">{record.instrument.name}</Text>
          </Space>
        ),
      },
      {
        title: "分类",
        dataIndex: "category",
        width: 110,
        render: (value: PositionCategory) => categoryLabels[value] || value,
      },
      { title: "总数量", dataIndex: "quantity", width: 110, align: "right" },
      {
        title: "可用数量",
        dataIndex: "availableQuantity",
        width: 110,
        align: "right",
      },
      {
        title: "冻结数量",
        dataIndex: "frozenQuantity",
        width: 110,
        align: "right",
      },
      {
        title: "成本价",
        dataIndex: "averagePrice",
        width: 130,
        align: "right",
        render: formatMoney,
      },
      {
        title: "现价",
        dataIndex: "lastPrice",
        width: 130,
        align: "right",
        render: formatMoney,
      },
      {
        title: "持仓市值",
        dataIndex: "marketValue",
        width: 150,
        align: "right",
        render: formatMoney,
      },
      {
        title: "浮动盈亏",
        dataIndex: "unrealizedPnl",
        width: 150,
        align: "right",
        render: (value) => (
          <Text type={Number(value) < 0 ? "danger" : "success"}>
            {formatMoney(value)}
          </Text>
        ),
      },
    ],
    [],
  );

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>客户持仓</Title>
          <Paragraph type="secondary">
            与客户 App 持仓同步，按涨停股、IPO、OTC 分类查看自己名下客户的真实持仓。
          </Paragraph>
        </div>

        {error && <Alert type="error" title={error} showIcon />}

        <Row gutter={[16, 16]}>
          <Col xs={24} md={8}>
            <Card>
              <Statistic
                title="持仓记录"
                value={summary?.count ?? 0}
                prefix={<HomeOutlined />}
                suffix="条"
              />
            </Card>
          </Col>
          <Col xs={24} md={8}>
            <Card>
              <Statistic
                title="持仓市值"
                value={Number(summary?.marketValue ?? 0)}
                prefix={<WalletOutlined />}
                formatter={(value) => formatMoney(value as number)}
              />
            </Card>
          </Col>
          <Col xs={24} md={8}>
            <Card>
              <Statistic
                title="浮动盈亏"
                value={totalPnl}
                valueStyle={{ color: totalPnl < 0 ? "#cf1322" : "#16a34a" }}
                formatter={(value) => formatMoney(value as number)}
              />
            </Card>
          </Col>
        </Row>

        <Card>
          <Space
            wrap
            style={{
              width: "100%",
              justifyContent: "space-between",
              marginBottom: 16,
            }}
          >
            <Input
              allowClear
              prefix={<SearchOutlined />}
              placeholder="搜索客户、手机号、交易账号、股票简称或公司名称"
              value={keyword}
              onChange={(event) => setKeyword(event.target.value)}
              onPressEnter={() => loadPositions(category)}
              style={{ width: 460 }}
            />
            <Button
              icon={<ReloadOutlined />}
              onClick={() => loadPositions(category)}
              loading={loading}
            >
              刷新
            </Button>
          </Space>

          <Tabs
            activeKey={category}
            onChange={(key) => setCategory(key as PositionCategory)}
            items={[
              {
                key: "INSTITUTIONAL",
                label: `涨停股 ${summary?.categories.INSTITUTIONAL ?? 0}`,
              },
              { key: "IPO", label: `IPO ${summary?.categories.IPO ?? 0}` },
              { key: "OTC", label: `OTC ${summary?.categories.OTC ?? 0}` },
            ]}
          />

          <Table<BusinessPosition>
            rowKey="id"
            columns={columns}
            dataSource={positions}
            loading={loading}
            scroll={{ x: 1450 }}
            pagination={{
              pageSize: 12,
              showTotal: (total) => `共 ${total} 条持仓`,
            }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
