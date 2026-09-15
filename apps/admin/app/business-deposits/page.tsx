"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from '@/lib/api';

const { Title, Paragraph, Text } = Typography;

type DepositRecord = {
  id: string;
  amount: string | number;
  status: string;
  referenceId?: string | null;
  note?: string | null;
  createdAt: string;
  account: {
    id: string;
    accountNumber: string;
    currency: string;
    user: {
      id: string;
      customerNo?: string | null;
      fullName: string;
      phone?: string | null;
      status: string;
    };
  };
  createdBy?: {
    fullName?: string | null;
    role?: string | null;
  } | null;
};

function formatMoney(value: string | number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export default function BusinessDepositsPage() {
  const [records, setRecords] = useState<DepositRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadRecords() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<DepositRecord[]>("/business/my-deposits");
      setRecords(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "入金记录加载失败",
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
        record.status,
      ];

      return values.some((value) =>
        String(value ?? "").toLowerCase().includes(normalized),
      );
    });
  }, [keyword, records]);

  const columns: ColumnsType<DepositRecord> = [
    {
      title: "客户",
      key: "customer",
      width: 240,
      fixed: "left",
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
      key: "accountNumber",
      width: 170,
      render: (_, record) => record.account.accountNumber,
    },
    {
      title: "入金金额",
      dataIndex: "amount",
      key: "amount",
      width: 150,
      align: "right",
      render: formatMoney,
    },
    {
      title: "状态",
      dataIndex: "status",
      key: "status",
      width: 120,
      render: (value) => <Tag color="green">{value === "COMPLETED" ? "已完成" : value}</Tag>,
    },
    {
      title: "流水号",
      dataIndex: "referenceId",
      key: "referenceId",
      width: 190,
      render: (value) => value || "-",
    },
    {
      title: "财务操作员",
      key: "operator",
      width: 150,
      render: (_, record) => record.createdBy?.fullName || record.createdBy?.role || "-",
    },
    {
      title: "备注",
      dataIndex: "note",
      key: "note",
      width: 220,
      render: (value) => value || "-",
    },
    {
      title: "完成时间",
      dataIndex: "createdAt",
      key: "createdAt",
      width: 180,
      render: formatDate,
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>客户入金记录</Title>
          <Paragraph type="secondary">
            这里只显示自己名下客户已由财务完成上分的记录，业务员没有审核或上分权限。
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
              placeholder="搜索客户编号、姓名、手机号、交易账号或流水号"
              value={keyword}
              onChange={(event) => setKeyword(event.target.value)}
              style={{ width: 420 }}
            />

            <Button icon={<ReloadOutlined />} onClick={loadRecords} loading={loading}>
              刷新
            </Button>
          </Space>

          <Table<DepositRecord>
            rowKey="id"
            columns={columns}
            dataSource={filteredRecords}
            loading={loading}
            scroll={{ x: 1420 }}
            pagination={{
              pageSize: 20,
              showSizeChanger: true,
              showTotal: (total) => `共 ${total} 条入金记录`,
            }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
