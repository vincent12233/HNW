"use client";

import {
  CopyOutlined,
  PlusOutlined,
  ReloadOutlined,
  StopOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  InputNumber,
  message,
  Modal,
  Popconfirm,
  Space,
  Table,
  Tag,
  Typography,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph } = Typography;

type InviteCode = {
  id: string;
  code: string;
  status: "UNUSED" | "USED" | "EXPIRED" | "DISABLED";
  customerId?: string | null;
  expiresAt?: string | null;
  usedAt?: string | null;
  createdAt: string;
  customer?: {
    id: string;
    fullName: string;
    phone?: string | null;
  } | null;
};

const statusConfig = {
  UNUSED: { color: "blue", label: "未使用" },
  USED: { color: "green", label: "已使用" },
  EXPIRED: { color: "orange", label: "已过期" },
  DISABLED: { color: "red", label: "已作废" },
};

function formatDate(value?: string | null) {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

function responseText(error: any, fallback: string) {
  const value = error.response?.data?.message;
  return Array.isArray(value) ? value.join("，") : value || fallback;
}

export default function InviteCodesPage() {
  const [codes, setCodes] = useState<InviteCode[]>([]);
  const [loading, setLoading] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [generateOpen, setGenerateOpen] = useState(false);
  const [count, setCount] = useState(10);
  const [error, setError] = useState("");

  async function loadCodes() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<InviteCode[]>("/business/invite-codes");
      setCodes(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: any) {
      setError(responseText(requestError, "邀请码加载失败"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadCodes();
  }, []);

  async function generateCodes() {
    setGenerating(true);

    try {
      const userText = localStorage.getItem("adminUser");
      const user = userText ? JSON.parse(userText) : null;

      await api.post(`/business/${user?.id}/invite-codes`, {
        count,
      });

      message.success("邀请码生成成功");
      setGenerateOpen(false);
      await loadCodes();
    } catch (requestError: any) {
      message.error(responseText(requestError, "邀请码生成失败"));
    } finally {
      setGenerating(false);
    }
  }

  async function disableCode(id: string) {
    try {
      await api.patch(`/business/invite-codes/${id}/disable`);
      message.success("邀请码已作废");
      await loadCodes();
    } catch (requestError: any) {
      message.error(responseText(requestError, "邀请码作废失败"));
    }
  }

  async function copyCode(code: string) {
    await navigator.clipboard.writeText(code);
    message.success("邀请码已复制");
  }

  const columns: ColumnsType<InviteCode> = [
    {
      title: "邀请码",
      dataIndex: "code",
      key: "code",
      width: 190,
      fixed: "left",
      render: (code: string) => (
        <Space>
          <Typography.Text code>{code}</Typography.Text>
          <Button
            type="text"
            icon={<CopyOutlined />}
            onClick={() => copyCode(code)}
          />
        </Space>
      ),
    },
    {
      title: "状态",
      dataIndex: "status",
      key: "status",
      width: 120,
      render: (status: InviteCode["status"]) => {
        const config = statusConfig[status] ?? statusConfig.UNUSED;
        return <Tag color={config.color}>{config.label}</Tag>;
      },
    },
    {
      title: "使用客户",
      key: "customer",
      width: 180,
      render: (_, record) => record.customer?.fullName || "-",
    },
    {
      title: "手机号",
      key: "phone",
      width: 150,
      render: (_, record) => record.customer?.phone || "-",
    },
    {
      title: "生成时间",
      dataIndex: "createdAt",
      key: "createdAt",
      width: 180,
      render: formatDate,
    },
    {
      title: "使用时间",
      dataIndex: "usedAt",
      key: "usedAt",
      width: 180,
      render: formatDate,
    },
    {
      title: "操作",
      key: "actions",
      width: 130,
      fixed: "right",
      render: (_, record) =>
        record.status === "UNUSED" ? (
          <Popconfirm
            title="确认作废邀请码？"
            description="作废后该邀请码不能再用于客户注册。"
            onConfirm={() => disableCode(record.id)}
            okText="确认"
            cancelText="取消"
          >
            <Button danger icon={<StopOutlined />}>
              作废
            </Button>
          </Popconfirm>
        ) : (
          "-"
        ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>我的邀请码</Title>
          <Paragraph type="secondary">
            每个邀请码只能成功注册一个客户，使用后自动失效。
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
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={() => setGenerateOpen(true)}
            >
              生成邀请码
            </Button>

            <Button icon={<ReloadOutlined />} onClick={loadCodes} loading={loading}>
              刷新
            </Button>
          </Space>

          <Table<InviteCode>
            rowKey="id"
            columns={columns}
            dataSource={codes}
            loading={loading}
            scroll={{ x: 1150 }}
            pagination={{
              pageSize: 20,
              showSizeChanger: true,
              showTotal: (total) => `共 ${total} 个邀请码`,
            }}
          />
        </Card>

        <Modal
          title="生成邀请码"
          open={generateOpen}
          onCancel={() => setGenerateOpen(false)}
          onOk={generateCodes}
          confirmLoading={generating}
          okText="生成"
          cancelText="取消"
        >
          <Space orientation="vertical" style={{ width: "100%" }}>
            <Typography.Text>生成数量</Typography.Text>
            <InputNumber
              min={1}
              max={100}
              value={count}
              onChange={(value) => setCount(Number(value ?? 1))}
              style={{ width: "100%" }}
            />
            <Typography.Text type="secondary">
              每次最多生成 100 个一次性邀请码。
            </Typography.Text>
          </Space>
        </Modal>
      </Space>
    </AdminShell>
  );
}
