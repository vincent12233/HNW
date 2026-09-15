"use client";

import {
  GiftOutlined,
  LockOutlined,
  ReloadOutlined,
  SearchOutlined,
  TeamOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Input,
  message,
  Modal,
  Popconfirm,
  Space,
  Table,
  Tag,
  Typography,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from '@/lib/api';

const { Title, Paragraph } = Typography;

type BusinessUser = {
  id: string;
  userId: string;
  employeeNo: string;
  department?: string | null;
  isActive: boolean;
  createdAt: string;
  user: {
    id: string;
    fullName: string;
    phone?: string | null;
    role: string;
    status: string;
    createdAt: string;
    _count: {
      assignedCustomers: number;
    };
  };
  inviteCodes: Array<{
    id: string;
  }>;
  _count: {
    inviteCodes: number;
  };
};

type Customer = {
  id: string;
  fullName: string;
  phone?: string | null;
  status: string;
  createdAt: string;
  account?: {
    id: string;
    accountNumber: string;
    cashBalance: string | number;
    buyingPower: string | number;
    frozenBalance: string | number;
    currency: string;
  } | null;
  usedInviteCode?: {
    code: string;
    usedAt?: string | null;
  } | null;
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

export default function BusinessUsersPage() {
  const [records, setRecords] = useState<BusinessUser[]>([]);
  const [keyword, setKeyword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [customerOpen, setCustomerOpen] = useState(false);
  const [customerLoading, setCustomerLoading] = useState(false);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [selectedBusiness, setSelectedBusiness] = useState<BusinessUser | null>(
    null,
  );


  const [passwordOpen, setPasswordOpen] = useState(false);
  const [newPassword, setNewPassword] = useState("");
  const [passwordLoading, setPasswordLoading] = useState(false);

  async function loadRecords() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<BusinessUser[]>("/business");

      setRecords(
        Array.isArray(response.data) ? response.data : [response.data],
      );
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");

      setError(responseMessage || "业务员数据加载失败",
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

    if (!normalized) {
      return records;
    }

    return records.filter((record) => {
      const values = [
        record.employeeNo,
        record.user.fullName,
        record.user.phone,
        record.department,
      ];

      return values.some((value) =>
        String(value ?? "")
          .toLowerCase()
          .includes(normalized),
      );
    });
  }, [keyword, records]);

  async function openCustomers(record: BusinessUser) {
    setSelectedBusiness(record);
    setCustomerOpen(true);
    setCustomerLoading(true);
    setCustomers([]);

    try {
      const response = await api.get<Customer[]>(
        `/business/${record.userId}/customers`,
      );

      setCustomers(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");

      message.error(responseMessage || "客户数据加载失败",
      );
    } finally {
      setCustomerLoading(false);
    }
  }

  async function changeBusinessStatus(record: BusinessUser, isActive: boolean) {
    try {
      await api.patch(`/business/${record.userId}/status`, {
        isActive,
      });

      message.success(isActive ? "业务员已启用" : "业务员已停用");
      await loadRecords();
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");

      message.error(responseMessage || "状态修改失败",
      );
    }
  }

  function openPasswordModal(record: BusinessUser) {
    setSelectedBusiness(record);
    setNewPassword("");
    setPasswordOpen(true);
  }

  async function resetPassword() {
    if (!selectedBusiness) {
      return;
    }

    if (newPassword.length < 6) {
      message.error("新密码至少需要 6 个字符");
      return;
    }

    setPasswordLoading(true);

    try {
      await api.patch(`/business/${selectedBusiness.userId}/reset-password`, {
        newPassword,
      });

      message.success("业务员密码已重置");
      setPasswordOpen(false);
      setNewPassword("");
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");

      message.error(responseMessage || "密码重置失败",
      );
    } finally {
      setPasswordLoading(false);
    }
  }

  const customerColumns: ColumnsType<Customer> = [
    {
      title: "客户姓名",
      dataIndex: "fullName",
      key: "fullName",
      width: 150,
    },
    {
      title: "手机号",
      dataIndex: "phone",
      key: "phone",
      width: 140,
      render: (value) => value || "-",
    },
    {
      title: "交易账号",
      key: "accountNumber",
      width: 170,
      render: (_, record) => record.account?.accountNumber || "-",
    },
    {
      title: "现金余额",
      key: "cashBalance",
      width: 150,
      align: "right",
      render: (_, record) => formatMoney(record.account?.cashBalance),
    },
    {
      title: "可用资金",
      key: "buyingPower",
      width: 150,
      align: "right",
      render: (_, record) => formatMoney(record.account?.buyingPower),
    },
    {
      title: "邀请码",
      key: "inviteCode",
      width: 170,
      render: (_, record) => record.usedInviteCode?.code || "-",
    },
    {
      title: "状态",
      dataIndex: "status",
      key: "status",
      width: 100,
      render: (status: string) => (
        <Tag color={status === "ACTIVE" ? "green" : "red"}>
          {status === "ACTIVE" ? "正常" : status}
        </Tag>
      ),
    },
  ];

  const columns: ColumnsType<BusinessUser> = [
    {
      title: "员工编号",
      dataIndex: "employeeNo",
      key: "employeeNo",
      width: 130,
      fixed: "left",
    },
    {
      title: "姓名",
      key: "fullName",
      width: 150,
      render: (_, record) => record.user.fullName,
    },
    {
      title: "手机号",
      key: "phone",
      width: 140,
      render: (_, record) => record.user.phone || "-",
    },
    {
      title: "部门",
      dataIndex: "department",
      key: "department",
      width: 150,
      render: (value) => value || "-",
    },
    {
      title: "客户数量",
      key: "customers",
      width: 130,
      align: "right",
      render: (_, record) => (
        <Space>
          <TeamOutlined />
          {record.user._count.assignedCustomers}
        </Space>
      ),
    },
    {
      title: "可用邀请码",
      key: "unusedCodes",
      width: 140,
      align: "right",
      render: (_, record) => (
        <Space>
          <GiftOutlined />
          {record.inviteCodes.length}
        </Space>
      ),
    },
    {
      title: "邀请码总数",
      key: "totalCodes",
      width: 130,
      align: "right",
      render: (_, record) => record._count.inviteCodes,
    },
    {
      title: "已使用/失效",
      key: "usedCodes",
      width: 140,
      align: "right",
      render: (_, record) =>
        record._count.inviteCodes - record.inviteCodes.length,
    },
    {
      title: "状态",
      key: "status",
      width: 100,
      render: (_, record) => (
        <Tag color={record.isActive ? "green" : "red"}>
          {record.isActive ? "正常" : "已停用"}
        </Tag>
      ),
    },
    {
      title: "操作",
      key: "actions",
      width: 390,
      fixed: "right",
      render: (_, record) => (
        <Space wrap>
          <Button
            size="small"
            icon={<TeamOutlined />}
            onClick={() => openCustomers(record)}
          >
            查看客户
          </Button>

          <Popconfirm
            title={record.isActive ? "确认停用业务员？" : "确认启用业务员？"}
            description={
              record.isActive
                ? "停用后将不能继续生成新的邀请码。"
                : "启用后可以继续生成邀请码。"
            }
            okText="确认"
            cancelText="取消"
            onConfirm={() => changeBusinessStatus(record, !record.isActive)}
          >
            <Button danger={record.isActive} size="small">
              {record.isActive ? "停用" : "启用"}
            </Button>
          </Popconfirm>

          <Button
            size="small"
            icon={<LockOutlined />}
            onClick={() => openPasswordModal(record)}
          >
            重置密码
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>业务员管理</Title>

          <Paragraph type="secondary">
            管理业务员、客户归属、邀请码和登录密码。
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
              placeholder="搜索员工编号、姓名、手机号或部门"
              value={keyword}
              onChange={(event) => setKeyword(event.target.value)}
              style={{ width: 380 }}
            />

            <Button
              icon={<ReloadOutlined />}
              onClick={loadRecords}
              loading={loading}
            >
              刷新
            </Button>
          </Space>

          <Table<BusinessUser>
            rowKey="id"
            columns={columns}
            dataSource={filteredRecords}
            loading={loading}
            scroll={{ x: 1800 }}
            pagination={{
              pageSize: 20,
              showSizeChanger: true,
              showTotal: (total) => `共 ${total} 位业务员`,
            }}
          />
        </Card>
      </Space>

      <Modal
        title={
          selectedBusiness
            ? `${selectedBusiness.user.fullName} - 名下客户`
            : "名下客户"
        }
        open={customerOpen}
        onCancel={() => setCustomerOpen(false)}
        footer={null}
        width={1100}
      >
        <Table<Customer>
          rowKey="id"
          columns={customerColumns}
          dataSource={customers}
          loading={customerLoading}
          scroll={{ x: 1000 }}
          pagination={{
            pageSize: 10,
            showTotal: (total) => `共 ${total} 位客户`,
          }}
        />
      </Modal>

      <Modal
        title="重置业务员密码"
        open={passwordOpen}
        onCancel={() => setPasswordOpen(false)}
        onOk={resetPassword}
        confirmLoading={passwordLoading}
        okText="重置密码"
        cancelText="取消"
      >
        <Space orientation="vertical" style={{ width: "100%" }}>
          <Typography.Text>
            业务员：
            {selectedBusiness?.user.fullName || "-"}
          </Typography.Text>

          <Input.Password
            value={newPassword}
            onChange={(event) => setNewPassword(event.target.value)}
            placeholder="请输入至少 6 个字符的新密码"
            prefix={<LockOutlined />}
          />
        </Space>
      </Modal>
    </AdminShell>
  );
}
