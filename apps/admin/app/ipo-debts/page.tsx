"use client";

import {
  ExclamationCircleOutlined,
  ReloadOutlined,
  SearchOutlined,
} from "@ant-design/icons";
import { Button, Card, Col, Input, Row, Space, Statistic, Table, Tag, Typography } from "antd";
import { useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";

const { Title, Paragraph, Text } = Typography;

type IpoDebt = {
  orderNo: string;
  customerNo: string;
  customerName: string;
  phone: string;
  ipoName: string;
  symbol: string;
  allocatedQty: number;
  paidAmount: number;
  outstandingAmount: number;
  status: "待补款" | "已提醒" | "已逾期";
  dueDate: string;
};

const rows: IpoDebt[] = [
  {
    orderNo: "IPO20260809A101",
    customerNo: "HNW005F7F5779",
    customerName: "Sonal Naik",
    phone: "9722242100",
    ipoName: "Tata Capital Limited",
    symbol: "TATACAP",
    allocatedQty: 100,
    paidAmount: 52000,
    outstandingAmount: 50000,
    status: "待补款",
    dueDate: "2026-08-12",
  },
  {
    orderNo: "IPO20260809B208",
    customerNo: "HNW6C0A3C0A2A",
    customerName: "Aarav Sharma",
    phone: "9876543210",
    ipoName: "National Securities Depository",
    symbol: "NSDL",
    allocatedQty: 50,
    paidAmount: 0,
    outstandingAmount: 42250,
    status: "已提醒",
    dueDate: "2026-08-11",
  },
  {
    orderNo: "IPO20260809C309",
    customerNo: "HNW21A8F4071",
    customerName: "Priya Mehta",
    phone: "9811122233",
    ipoName: "Laxmi Dental Ltd",
    symbol: "LAXMI",
    allocatedQty: 33,
    paidAmount: 0,
    outstandingAmount: 13761,
    status: "已逾期",
    dueDate: "2026-08-08",
  },
];

function formatMoney(value: number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(value);
}

export default function IpoDebtsPage() {
  const [keyword, setKeyword] = useState("");

  const filteredRows = useMemo(() => {
    const query = keyword.trim().toLowerCase();
    if (!query) return rows;

    return rows.filter((row) =>
      [
        row.orderNo,
        row.customerNo,
        row.customerName,
        row.phone,
        row.ipoName,
        row.symbol,
        row.status,
      ]
        .join(" ")
        .toLowerCase()
        .includes(query),
    );
  }, [keyword]);

  const totalOutstanding = filteredRows.reduce((sum, row) => sum + row.outstandingAmount, 0);
  const overdueCount = filteredRows.filter((row) => row.status === "已逾期").length;

  return (
    <AdminShell>
      <Space direction="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>IPO 欠款</Title>
          <Paragraph type="secondary">
            用于跟进 IPO 中签后未完成补款的客户。当前页面为后台运营模块，后续可接入真实 IPO 分配和扣款数据。
          </Paragraph>
        </div>

        <Row gutter={[16, 16]}>
          <Col xs={24} md={8}>
            <Card style={{ borderRadius: 8 }}>
              <Statistic title="欠款总额" value={formatMoney(totalOutstanding)} />
            </Card>
          </Col>
          <Col xs={24} md={8}>
            <Card style={{ borderRadius: 8 }}>
              <Statistic title="待跟进订单" value={filteredRows.length} />
            </Card>
          </Col>
          <Col xs={24} md={8}>
            <Card style={{ borderRadius: 8 }}>
              <Statistic title="逾期订单" value={overdueCount} prefix={<ExclamationCircleOutlined />} />
            </Card>
          </Col>
        </Row>

        <Card
          title="欠款列表"
          extra={
            <Space>
              <Input
                prefix={<SearchOutlined />}
                allowClear
                placeholder="搜索订单号、客户编号、手机号或 IPO"
                value={keyword}
                onChange={(event) => setKeyword(event.target.value)}
                style={{ width: 340 }}
              />
              <Button icon={<ReloadOutlined />}>刷新</Button>
            </Space>
          }
          style={{ borderRadius: 8 }}
        >
          <Table<IpoDebt>
            rowKey="orderNo"
            dataSource={filteredRows}
            pagination={{ pageSize: 10 }}
            columns={[
              {
                title: "订单号",
                dataIndex: "orderNo",
                render: (value) => <Text strong>{value}</Text>,
              },
              {
                title: "客户",
                render: (_, row) => (
                  <Space direction="vertical" size={0}>
                    <Text>{row.customerName}</Text>
                    <Text type="secondary">{row.customerNo} / +91 {row.phone}</Text>
                  </Space>
                ),
              },
              {
                title: "IPO",
                render: (_, row) => (
                  <Space direction="vertical" size={0}>
                    <Text>{row.ipoName}</Text>
                    <Text type="secondary">{row.symbol}</Text>
                  </Space>
                ),
              },
              { title: "中签数量", dataIndex: "allocatedQty", render: (value) => `${value} 股` },
              { title: "已付金额", dataIndex: "paidAmount", render: formatMoney },
              {
                title: "欠款金额",
                dataIndex: "outstandingAmount",
                render: (value) => <Text type="danger">{formatMoney(value)}</Text>,
              },
              { title: "补款截止", dataIndex: "dueDate" },
              {
                title: "状态",
                dataIndex: "status",
                render: (value: IpoDebt["status"]) => {
                  const color = value === "已逾期" ? "red" : value === "已提醒" ? "orange" : "blue";
                  return <Tag color={color}>{value}</Tag>;
                },
              },
              {
                title: "操作",
                render: () => (
                  <Space>
                    <Button size="small">提醒客户</Button>
                    <Button size="small" type="primary">标记已跟进</Button>
                  </Space>
                ),
              },
            ]}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
