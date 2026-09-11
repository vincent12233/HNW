"use client";

import { CheckOutlined, CloseOutlined, ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Input,
  Modal,
  Popconfirm,
  Space,
  Table,
  Tag,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

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
    accountNumber: string;
    user: {
      id: string;
      fullName: string;
      phone?: string | null;
      customerNo?: string | null;
    };
  };
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

function payoutMethod(record: WithdrawalRecord) {
  if (record.upiId) return `UPI：${record.upiId}`;
  const parts = [record.bankName, record.accountNumber, record.ifscCode].filter(Boolean);
  return parts.length > 0 ? parts.join(" / ") : "-";
}

export default function WithdrawalsPage() {
  const [records, setRecords] = useState<WithdrawalRecord[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [rejecting, setRejecting] = useState<WithdrawalRecord | null>(null);
  const [rejectNote, setRejectNote] = useState("");
  const [submittingId, setSubmittingId] = useState("");
  const submitting = useRef(false);

  async function loadRecords() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<WithdrawalRecord[]>("/withdrawal/pending");
      setRecords(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      setError(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "提现申请加载失败",
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
        record.orderNo,
        record.account.user.customerNo,
        record.account.user.fullName,
        record.account.user.phone,
        record.account.accountNumber,
        record.upiId,
        record.bankName,
        record.accountNumber,
        record.ifscCode,
      ];

      return values.some((value) =>
        String(value ?? "").toLowerCase().includes(normalized),
      );
    });
  }, [keyword, records]);

  async function approve(record: WithdrawalRecord) {
    if (submitting.current || loading || error) return;
    submitting.current = true;
    setSubmittingId(record.id);
    try {
      await api.patch(`/withdrawal/${record.id}/approve`);
      message.success("提现已通过");
      await loadRecords();
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      message.error(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "提现通过失败",
      );
    } finally {
      submitting.current = false;
      setSubmittingId("");
    }
  }

  async function reject() {
    if (!rejecting) return;
    if (submitting.current || loading || error) return;
    if (rejectNote.trim().length < 3) {
      message.error("请输入至少 3 个字符的拒绝原因");
      return;
    }

    submitting.current = true;
    setSubmittingId(rejecting.id);
    try {
      await api.patch(`/withdrawal/${rejecting.id}/reject`, {
        note: rejectNote,
      });
      message.success("提现已拒绝");
      setRejecting(null);
      setRejectNote("");
      await loadRecords();
    } catch (requestError: any) {
      const responseMessage = requestError.response?.data?.message;
      message.error(
        Array.isArray(responseMessage)
          ? responseMessage.join("，")
          : responseMessage || "提现拒绝失败",
      );
    } finally {
      submitting.current = false;
      setSubmittingId("");
    }
  }

  const columns: ColumnsType<WithdrawalRecord> = [
    {
      title: "订单号",
      dataIndex: "orderNo",
      fixed: "left",
      width: 180,
      render: (value) => <Text copyable>{value || "-"}</Text>,
    },
    {
      title: "客户",
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
    { title: "交易账号", width: 170, render: (_, record) => record.account.accountNumber },
    {
      title: "金额",
      width: 150,
      align: "right",
      render: (_, record) => formatMoney(record.amount),
    },
    { title: "收款信息", width: 280, render: (_, record) => payoutMethod(record) },
    { title: "备注", dataIndex: "note", width: 180, render: (value) => value || "-" },
    {
      title: "状态",
      dataIndex: "status",
      width: 110,
      render: (value) => <Tag color="orange">{value === "PENDING" ? "待审核" : value}</Tag>,
    },
    { title: "申请时间", dataIndex: "createdAt", width: 180, render: formatDate },
    {
      title: "操作",
      fixed: "right",
      width: 180,
      render: (_, record) => (
        <Space>
          <Popconfirm title="确认通过提现申请？" description={`${record.account.user.fullName} · ${formatMoney(record.amount)} · ${payoutMethod(record)}`}
            okText="确认通过" cancelText="取消" onConfirm={() => approve(record)} disabled={!!submittingId}>
          <Button
            type="primary"
            size="small"
            icon={<CheckOutlined />}
            loading={submittingId === record.id}
            disabled={!!submittingId && submittingId !== record.id}
          >
            通过
          </Button>
          </Popconfirm>
          <Button danger size="small" icon={<CloseOutlined />} disabled={!!submittingId} onClick={() => setRejecting(record)}>
            拒绝
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>提现审核</Title>
          <Paragraph type="secondary">
            财务确认客户收款信息后，通过或拒绝提现申请。可通过订单号、客户编号、手机号或交易账号查找。
          </Paragraph>
        </div>

        {error && <Alert type="error" showIcon title={error} />}

        <Card>
          <Space wrap style={{ width: "100%", justifyContent: "space-between", marginBottom: 16 }}>
            <Input
              allowClear
              prefix={<SearchOutlined />}
              placeholder="搜索订单号、客户编号、手机号、交易账号或收款信息"
              value={keyword}
              onChange={(event) => setKeyword(event.target.value)}
              style={{ width: 460 }}
            />
            <Button icon={<ReloadOutlined />} loading={loading} onClick={loadRecords}>
              刷新
            </Button>
          </Space>

          <Table<WithdrawalRecord>
            rowKey="id"
            columns={columns}
            dataSource={filteredRecords}
            loading={loading}
            scroll={{ x: 1540 }}
          />
        </Card>
      </Space>

      <Modal
        title="拒绝提现"
        open={!!rejecting}
        onCancel={() => {
          if (submitting.current) return;
          setRejecting(null);
          setRejectNote("");
        }}
        onOk={reject}
        confirmLoading={!!submittingId}
        okText="确认拒绝"
        cancelText="取消"
      >
        <Input.TextArea
          rows={4}
          value={rejectNote}
          onChange={(event) => setRejectNote(event.target.value)}
          placeholder="请输入拒绝原因"
        />
      </Modal>
    </AdminShell>
  );
}
