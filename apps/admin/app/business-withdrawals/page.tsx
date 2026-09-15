"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Select, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from '@/lib/api';

const { Title, Paragraph, Text } = Typography;

type WithdrawalRecord = {
  id: string;
  orderNo?: string | null;
  amount: string | number;
  bankName?: string | null;
  accountNumber?: string | null;
  ifscCode?: string | null;
  upiId?: string | null;
  note?: string | null;
  status: string;
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

function statusTag(status: string) {
  const map: Record<string, { color: string; label: string }> = {
    PENDING: { color: "orange", label: "待财务审核" },
    APPROVED: { color: "green", label: "已通过" },
    REJECTED: { color: "red", label: "已拒绝" },
  };

  const config = map[status] ?? { color: "default", label: status };
  return <Tag color={config.color}>{config.label}</Tag>;
}

function payoutMethod(record: WithdrawalRecord) {
  const mask = (value?: string | null, visible = 4) => value ? `${"•".repeat(Math.max(4, value.length - visible))}${value.slice(-visible)}` : null;
  if (record.upiId) {
    const [name, provider] = record.upiId.split("@");
    return `UPI：${mask(name, 2)}${provider ? `@${provider}` : ""}`;
  }
  const parts = [record.bankName, mask(record.accountNumber), record.ifscCode ? `${record.ifscCode.slice(0, 4)}•••` : null].filter(Boolean);
  return parts.length > 0 ? parts.join(" / ") : "-";
}

export default function BusinessWithdrawalsPage() {
  const [records, setRecords] = useState<WithdrawalRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [statusFilter, setStatusFilter] = useState<"ALL" | "PENDING" | "APPROVED" | "REJECTED">("ALL");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function loadRecords() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<WithdrawalRecord[]>("/business/my-withdrawals");
      setRecords(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      setError(responseMessage || "提现记录加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadRecords();
  }, []);

  const filteredRecords = useMemo(() => {
    const byStatus =
      statusFilter === "ALL"
        ? records
        : records.filter((record) => record.status === statusFilter);
    const normalized = keyword.trim().toLowerCase();
    if (!normalized) return byStatus;

    return byStatus.filter((record) => {
      const values = [
        record.orderNo,
        record.account.user.customerNo,
        record.account.user.fullName,
        record.account.user.phone,
        record.account.accountNumber,
        record.upiId,
        record.bankName,
        record.accountNumber,
        record.ifscCode,
        record.status,
      ];

      return values.some((value) =>
        String(value ?? "").toLowerCase().includes(normalized),
      );
    });
  }, [keyword, records, statusFilter]);

  const columns: ColumnsType<WithdrawalRecord> = [
    {
      title: "订单号",
      dataIndex: "orderNo",
      width: 180,
      fixed: "left",
      render: (value) => <Text copyable>{value || "-"}</Text>,
    },
    {
      title: "客户",
      key: "customer",
      width: 240,
      render: (_, record) => (
        <Space orientation="vertical" size={0}>
          <Text strong>{record.account.user.fullName || "未命名客户"}</Text>
          <Text type="secondary">
            {record.account.user.customerNo || "-"} / +91 {record.account.user.phone || "-"}
          </Text>
        </Space>
      ),
    },
    { title: "交易账号", key: "tradingAccount", width: 170, render: (_, record) => record.account.accountNumber },
    {
      title: "提现金额",
      dataIndex: "amount",
      key: "amount",
      width: 150,
      align: "right",
      render: formatMoney,
    },
    { title: "收款信息", key: "payoutMethod", width: 280, render: (_, record) => payoutMethod(record) },
    { title: "状态", dataIndex: "status", key: "status", width: 130, render: statusTag },
    { title: "备注", dataIndex: "note", key: "note", width: 220, render: (value) => value || "-" },
    { title: "申请时间", dataIndex: "createdAt", key: "createdAt", width: 180, render: formatDate },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>客户提现记录</Title>
          <Paragraph type="secondary">
            这里只显示自己名下客户的提现申请和处理结果，审核由财务后台完成。
          </Paragraph>
        </div>

        {error && <Alert type="error" title={error} showIcon />}

        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Space wrap>
              <Input
                allowClear
                prefix={<SearchOutlined />}
                placeholder="搜索订单号、客户编号、手机号、交易账号、UPI 或银行信息"
                value={keyword}
                onChange={(event) => setKeyword(event.target.value)}
                style={{ width: 420 }}
              />
              <Select
                value={statusFilter}
                style={{ width: 160 }}
                onChange={(value: "ALL" | "PENDING" | "APPROVED" | "REJECTED") => setStatusFilter(value)}
                options={[
                  { value: "ALL", label: "全部状态" },
                  { value: "PENDING", label: "待审核" },
                  { value: "APPROVED", label: "已通过" },
                  { value: "REJECTED", label: "已拒绝" },
                ]}
              />
            </Space>

            <Button icon={<ReloadOutlined />} onClick={loadRecords} loading={loading}>
              刷新
            </Button>
          </Space>

          <Table<WithdrawalRecord>
            rowKey="id"
            columns={columns}
            dataSource={filteredRecords}
            loading={loading}
            scroll={{ x: 1580 }}
            pagination={{
              pageSize: 20,
              showSizeChanger: true,
              showTotal: (total) => `共 ${total} 条提现记录`,
            }}
          />
        </Card>
      </Space>
    </AdminShell>
  );
}
