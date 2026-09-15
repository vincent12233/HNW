"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Input,
  Space,
  Table,
  Tag,
  Typography,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from '@/lib/api';

const { Title, Paragraph, Text } = Typography;

type InstitutionalStock = {
  id: string;
  symbol: string;
  name: string;
  market: string;
  category: string;
  status: string;
  reason?: string | null;
  expectedReturn?: string | null;
  risk?: string | null;
};

export default function BusinessInstitutionalPage() {
  const [items, setItems] = useState<InstitutionalStock[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadItems() {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<InstitutionalStock[]>(
        "/admin-products/watchlist",
      );
      setItems(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "涨停股加载失败",
      );
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
    return items.filter((item) =>
      [
        item.symbol,
        item.name,
        item.market,
        item.category,
        item.status,
        item.reason,
      ].some((field) =>
        String(field ?? "")
          .toLowerCase()
          .includes(value),
      ),
    );
  }, [items, keyword]);

  const columns: ColumnsType<InstitutionalStock> = [
    {
      title: "股票",
      key: "stock",
      width: 240,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.symbol}</Text>
          <Text type="secondary">{record.name}</Text>
        </Space>
      ),
    },
    { title: "市场", dataIndex: "market", width: 120 },
    { title: "分类", dataIndex: "category", width: 140 },
    {
      title: "预期收益",
      dataIndex: "expectedReturn",
      width: 130,
      render: (value) => (value ? <Text type="success">{value}%</Text> : "-"),
    },
    {
      title: "风险",
      dataIndex: "risk",
      width: 110,
      render: (value) => value || "-",
    },
    {
      title: "状态",
      dataIndex: "status",
      width: 120,
      render: (value) => (
        <Tag color={["ACTIVE", "展示中"].includes(value) ? "green" : "default"}>
          {value === "ACTIVE" ? "已启用" : value}
        </Tag>
      ),
    },
    { title: "推荐理由", dataIndex: "reason", render: (value) => value || "-" },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>涨停股</Title>
          <Paragraph type="secondary">
            此处同步展示超级管理员已启用的涨停股（机构股票），业务员可查看并向客户跟进。
            涨停股成交按实时行情结算；与客户端普通股票「自选股」不是同一产品。
          </Paragraph>
        </div>
        {error && <Alert type="error" title={error} showIcon />}
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
              placeholder="搜索简称、公司名称、市场、分类或状态"
              value={keyword}
              onChange={(event) => setKeyword(event.target.value)}
              style={{ width: 420 }}
            />
            <Button
              icon={<ReloadOutlined />}
              onClick={loadItems}
              loading={loading}
            >
              刷新
            </Button>
          </Space>
          <Table<InstitutionalStock>
            rowKey="id"
            columns={columns}
            dataSource={filtered}
            loading={loading}
            pagination={{
              pageSize: 15,
              showTotal: (total) => `共 ${total} 条涨停股`,
            }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
