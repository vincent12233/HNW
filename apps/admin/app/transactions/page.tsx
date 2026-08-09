"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Select, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type TransactionRecord = {
  id: string;
  type: string;
  status: string;
  amount: string;
  balanceBefore: string;
  balanceAfter: string;
  referenceId?: string | null;
  note?: string | null;
  createdAt: string;
  account: {
    accountNumber: string;
    user: {
      customerNo?: string | null;
      fullName: string;
      phone?: string | null;
    };
  };
  createdBy?: {
    fullName?: string | null;
    role?: string | null;
  } | null;
};

type TransactionResponse = {
  data: TransactionRecord[];
  pagination: {
    total: number;
    page: number;
    pageSize: number;
  };
};

const typeLabels: Record<string, string> = {
  ADMIN_CREDIT: "财务上分",
  ADMIN_DEBIT: "后台扣款",
  WITHDRAWAL: "提现",
  TRADE_SETTLEMENT: "交易结算",
  IPO_REPAYMENT: "IPO 还款",
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

export default function TransactionsPage() {
  const [records, setRecords] = useState<TransactionRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [type, setType] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadRecords(nextType = type) {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<TransactionResponse>("/admin/accounts/transactions", {
        params: {
          page: 1,
          pageSize: 100,
          type: nextType,
        },
      });
      setRecords(Array.isArray(response.data.data) ? response.data.data : []);
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "资金流水加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadRecords();
  }, []);

  const filteredRecords = useMemo(() => {
    const normalized = keyword.trim().toLowerCase();

    if (!normalized) return records;

    return records.filter((record) => {
      const values = [
        record.account.user.customerNo,
        record.account.user.fullName,
        record.account.user.phone,
        record.account.accountNumber,
        record.referenceId,
        record.note,
        record.type,
        record.status,
      ];

      return values.some((value) =>
        String(value ?? "").toLowerCase().includes(normalized),
      );
    });
  }, [keyword, records]);

  const columns: ColumnsType<TransactionRecord> = [
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
    {
      title: "交易账号",
      width: 170,
      render: (_, record) => record.account.accountNumber,
    },
    {
      title: "类型",
      dataIndex: "type",
      width: 150,
      render: (value) => (
        <Tag color={value === "ADMIN_CREDIT" ? "green" : value === "WITHDRAWAL" ? "gold" : "blue"}>
          {typeLabels[value] || value}
        </Tag>
      ),
    },
    {
      title: "金额",
      dataIndex: "amount",
      width: 150,
      align: "right",
      render: formatMoney,
    },
    {
      title: "变动前",
      dataIndex: "balanceBefore",
      width: 150,
      align: "right",
      render: formatMoney,
    },
    {
      title: "变动后",
      dataIndex: "balanceAfter",
      width: 150,
      align: "right",
      render: formatMoney,
    },
    {
      title: "流水号",
      dataIndex: "referenceId",
      width: 190,
      render: (value) => value || "-",
    },
    {
      title: "操作员",
      width: 150,
      render: (_, record) => record.createdBy?.fullName || record.createdBy?.role || "-",
    },
    {
      title: "时间",
      dataIndex: "createdAt",
      width: 180,
      render: formatDate,
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>资金流水</Title>
          <Paragraph type="secondary">
            查看所有客户账户的上分、提现、交易结算和系统资金变动。
          </Paragraph>
        </div>

        {error && <Alert type="error" showIcon title={error} />}

        <Card>
          <Space wrap>
            <Input
              allowClear
              prefix={<SearchOutlined />}
              placeholder="搜索客户、手机号、交易账号、客户编号、流水号"
              value={keyword}
              onChange={(event) => setKeyword(event.target.value)}
              style={{ width: 360 }}
            />
            <Select
              allowClear
              placeholder="流水类型"
              value={type}
              onChange={(value) => {
                setType(value);
                loadRecords(value);
              }}
              style={{ width: 220 }}
              options={[
                { value: "ADMIN_CREDIT", label: "财务上分" },
                { value: "WITHDRAWAL", label: "提现" },
                { value: "TRADE_SETTLEMENT", label: "交易结算" },
                { value: "IPO_REPAYMENT", label: "IPO 还款" },
                { value: "ADMIN_DEBIT", label: "后台扣款" },
              ]}
            />
            <Button icon={<ReloadOutlined />} loading={loading} onClick={() => loadRecords()}>
              查询
            </Button>
          </Space>

          <Table<TransactionRecord>
            rowKey="id"
            columns={columns}
            dataSource={filteredRecords}
            loading={loading}
            scroll={{ x: 1540 }}
            style={{ marginTop: 16 }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
