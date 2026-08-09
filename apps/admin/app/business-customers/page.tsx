"use client";

import {
  HistoryOutlined,
  ReloadOutlined,
  SafetyCertificateOutlined,
  SearchOutlined,
  WarningOutlined,
} from "@ant-design/icons";

import {
  Alert,
  Button,
  Card,
  Col,
  Input,
  Modal,
  Row,
  Space,
  Statistic,
  Table,
  Tag,
  Typography,
} from "antd";

import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type InviteCode = {
  id: string;
  code: string;
  usedAt?: string | null;
};

type Account = {
  id: string;

  accountNumber: string;

  cashBalance: string | number;

  buyingPower: string | number;

  frozenBalance: string | number;

  currency: string;

  isSandbox: boolean;
};

type LoginAudit = {
  id?: string;

  userId?: string;

  ipAddress?: string | null;

  userAgent?: string | null;

  createdAt: string;

  success: boolean;
};

type AssignedBusiness = {
  id: string;

  fullName: string;

  businessProfile?: {
    employeeNo?: string | null;
  } | null;
};

type LoginRisk = {
  customer: {
    id: string;

    fullName: string;
  };

  failedLoginCount24h: number;

  riskLevel: "LOW" | "MEDIUM" | "HIGH";

  lastFailedLogin?: LoginAudit | null;

  lastSuccessfulLogin?: LoginAudit | null;
};

type SharedCustomer = {
  id: string;

  fullName: string;

  phone?: string | null;

  lastLoginAt: string;

  assignedBusiness?: AssignedBusiness | null;
};

type SharedIpRisk = {
  ipAddress: string;

  customerCount: number;

  customers: SharedCustomer[];
};

type SharedDeviceRisk = {
  userAgent: string;

  customerCount: number;

  customers: SharedCustomer[];
};

type Customer = {
  id: string;

  customerNo?: string | null;

  fullName: string;

  phone?: string | null;

  status: string;

  createdAt: string;

  account?: Account | null;

  usedInviteCode?: InviteCode | null;

  loginAudits?: LoginAudit[];

  loginRisk?: LoginRisk | null;
};

function formatMoney(value?: string | number | null) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

function formatDate(value?: string | null) {
  if (!value) {
    return "-";
  }

  return new Date(value).toLocaleString("zh-CN");
}

function getDeviceLabel(userAgent?: string | null) {
  if (!userAgent) {
    return "-";
  }

  const ua = userAgent.toLowerCase();

  let platform = "未知设备";

  let browser = "未知客户端";

  if (ua.includes("android")) {
    platform = "Android";
  } else if (ua.includes("iphone") || ua.includes("ipad")) {
    platform = "iOS";
  } else if (ua.includes("windows")) {
    platform = "Windows";
  } else if (ua.includes("mac")) {
    platform = "macOS";
  }

  if (ua.includes("windowspowershell")) {
    browser = "PowerShell";
  } else if (ua.includes("edg/")) {
    browser = "Edge";
  } else if (ua.includes("chrome/")) {
    browser = "Chrome";
  } else if (ua.includes("firefox/")) {
    browser = "Firefox";
  } else if (ua.includes("safari/")) {
    browser = "Safari";
  }

  return `${platform} / ${browser}`;
}

function riskTag(level?: string) {
  if (level === "HIGH") {
    return {
      color: "red",

      text: "高风险",
    };
  }

  if (level === "MEDIUM") {
    return {
      color: "orange",

      text: "注意",
    };
  }

  return {
    color: "green",

    text: "正常",
  };
}

export default function BusinessCustomersPage() {
  const [customers, setCustomers] = useState<Customer[]>([]);

  const [keyword, setKeyword] = useState("");

  const [loading, setLoading] = useState(false);

  const [error, setError] = useState("");

  const [sharedIpRisks, setSharedIpRisks] = useState<SharedIpRisk[]>([]);

  const [sharedDeviceRisks, setSharedDeviceRisks] = useState<
    SharedDeviceRisk[]
  >([]);

  const [historyOpen, setHistoryOpen] = useState(false);

  const [historyLoading, setHistoryLoading] = useState(false);

  const [loginHistory, setLoginHistory] = useState<LoginAudit[]>([]);

  const [riskOpen, setRiskOpen] = useState(false);

  const [riskLoading, setRiskLoading] = useState(false);

  const [selectedRisk, setSelectedRisk] = useState<LoginRisk | null>(null);

  const [sharedOpen, setSharedOpen] = useState(false);

  const [sharedType, setSharedType] = useState<"IP" | "DEVICE">("IP");

  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(
    null,
  );

  async function loadCustomers() {
    setLoading(true);

    setError("");

    try {
      const customerResponse = await api.get<Customer[]>(
        "/business/my-customers",
      );

      const list = Array.isArray(customerResponse.data)
        ? customerResponse.data
        : [];

      const [ipResponse, deviceResponse] = await Promise.all([
        api.get<SharedIpRisk[]>("/business/shared-ip-risks"),

        api.get<SharedDeviceRisk[]>("/business/shared-device-risks"),
      ]);

      setSharedIpRisks(Array.isArray(ipResponse.data) ? ipResponse.data : []);

      setSharedDeviceRisks(
        Array.isArray(deviceResponse.data) ? deviceResponse.data : [],
      );

      const riskResults = await Promise.allSettled(
        list.map((customer) =>
          api.get<LoginRisk>(`/business/customers/${customer.id}/login-risk`),
        ),
      );

      setCustomers(
        list.map((customer, index) => {
          const result = riskResults[index];

          if (result.status === "fulfilled") {
            return {
              ...customer,

              loginRisk: result.value.data,
            };
          }

          return customer;
        }),
      );
    } catch (error: any) {
      const message = error.response?.data?.message;

      setError(
        Array.isArray(message)
          ? message.join("，")
          : message || "客户数据加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadCustomers();
  }, []);

  function customerHasSharedIp(id: string) {
    return sharedIpRisks.some((risk) =>
      risk.customers.some((customer) => customer.id === id),
    );
  }

  function customerHasSharedDevice(id: string) {
    return sharedDeviceRisks.some((risk) =>
      risk.customers.some((customer) => customer.id === id),
    );
  }

  async function openLoginHistory(customer: Customer) {
    setSelectedCustomer(customer);

    setHistoryOpen(true);

    setHistoryLoading(true);

    try {
      const response = await api.get<LoginAudit[]>(
        `/business/customers/${customer.id}/login-audits`,
      );

      setLoginHistory(Array.isArray(response.data) ? response.data : []);
    } catch {
      setLoginHistory([]);
    } finally {
      setHistoryLoading(false);
    }
  }

  async function openLoginRisk(customer: Customer) {
    setSelectedCustomer(customer);

    setRiskOpen(true);

    setRiskLoading(true);

    setSelectedRisk(null);

    try {
      const response = await api.get<LoginRisk>(
        `/business/customers/${customer.id}/login-risk`,
      );

      setSelectedRisk(response.data);
    } finally {
      setRiskLoading(false);
    }
  }

  function openShared(type: "IP" | "DEVICE") {
    setSharedType(type);

    setSharedOpen(true);
  }

  const filteredCustomers = useMemo(() => {
    const key = keyword.trim().toLowerCase();

    if (!key) {
      return customers;
    }

    return customers.filter((customer) => {
      const values = [
        customer.fullName,

        customer.customerNo,

        customer.phone,

        customer.account?.accountNumber,

        customer.usedInviteCode?.code,

        customer.loginRisk?.riskLevel,
      ];

      return values.some((value) =>
        String(value ?? "")
          .toLowerCase()
          .includes(key),
      );
    });
  }, [customers, keyword]);

  const columns: ColumnsType<Customer> = [
    {
      title: "客户姓名",

      dataIndex: "fullName",

      width: 160,

      fixed: "left",
    },

    {
      title: "客户编号",

      dataIndex: "customerNo",

      width: 140,

      render: (value) => value || "-",
    },

    {
      title: "手机号",

      dataIndex: "phone",

      width: 140,

      render: (value) => (value ? `+91 ${value}` : "-"),
    },

    {
      title: "交易账号",

      width: 170,

      render: (_, record) => record.account?.accountNumber || "-",
    },

    {
      title: "现金余额",

      width: 150,

      render: (_, record) => formatMoney(record.account?.cashBalance),
    },

    {
      title: "最近IP",

      width: 160,

      render: (_, record) => record.loginAudits?.[0]?.ipAddress || "-",
    },

    {
      title: "登录设备",

      width: 180,

      render: (_, record) => getDeviceLabel(record.loginAudits?.[0]?.userAgent),
    },

    {
      title: "24小时失败",

      width: 120,

      render: (_, record) => (
        <Tag
          color={
            (record.loginRisk?.failedLoginCount24h ?? 0) > 0
              ? "orange"
              : "green"
          }
        >
          {record.loginRisk?.failedLoginCount24h ?? 0}
        </Tag>
      ),
    },

    {
      title: "登录风险",

      width: 120,

      render: (_, record) => {
        const tag = riskTag(record.loginRisk?.riskLevel);

        return <Tag color={tag.color}>{tag.text}</Tag>;
      },
    },

    {
      title: "共享IP",

      width: 120,

      render: (_, record) =>
        customerHasSharedIp(record.id) ? (
          <Tag color="red">共享IP</Tag>
        ) : (
          <Tag color="green">正常</Tag>
        ),
    },

    {
      title: "共享设备",

      width: 130,

      render: (_, record) =>
        customerHasSharedDevice(record.id) ? (
          <Tag color="orange">共享设备</Tag>
        ) : (
          <Tag color="green">正常</Tag>
        ),
    },

    {
      title: "账户状态",

      dataIndex: "status",

      width: 110,

      render: (value) => (
        <Tag color={value === "ACTIVE" ? "green" : "red"}>
          {value === "ACTIVE" ? "正常" : "停用"}
        </Tag>
      ),
    },

    {
      title: "操作",

      width: 260,

      fixed: "right",

      render: (_, record) => (
        <Space>
          <Button
            size="small"

            icon={<HistoryOutlined />}

            onClick={() => openLoginHistory(record)}
          >
            登录记录
          </Button>

          <Button
            size="small"

            icon={<SafetyCertificateOutlined />}

            onClick={() => openLoginRisk(record)}
          >
            风险
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <AdminShell>
      <Space
        orientation="vertical"
        size="large"
        style={{
          width: "100%",
        }}
      >
        <div>
          <Title level={2}>我的客户</Title>

          <Paragraph type="secondary">
            查看客户资金、登录风险、共享 IP 和共享设备风险。
          </Paragraph>
        </div>

        {error && <Alert type="error" showIcon title={error} />}

        <Row gutter={[16, 16]}>
          <Col xs={24} sm={8}>
            <Card>
              <Statistic
                title="客户数量"

                value={customers.length}

                prefix={<SafetyCertificateOutlined />}
              />
            </Card>
          </Col>

          <Col xs={24} sm={8}>
            <Card
              hoverable
              onClick={() => {
                openShared("IP");
              }}
            >
              <Statistic
                title="共享IP风险客户"

                value={
                  new Set(
                    sharedIpRisks.flatMap((item) =>
                      item.customers.map((c) => c.id),
                    ),
                  ).size
                }

                prefix={<WarningOutlined />}
              />
            </Card>
          </Col>

          <Col xs={24} sm={8}>
            <Card
              hoverable
              onClick={() => {
                openShared("DEVICE");
              }}
            >
              <Statistic
                title="共享设备风险客户"

                value={
                  new Set(
                    sharedDeviceRisks.flatMap((item) =>
                      item.customers.map((c) => c.id),
                    ),
                  ).size
                }

                prefix={<WarningOutlined />}
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

              placeholder="搜索姓名、客户编号、手机号、交易账号"

              value={keyword}

              onChange={(e) => setKeyword(e.target.value)}

              style={{
                width: 420,
              }}
            />

            <Button
              icon={<ReloadOutlined />}

              loading={loading}

              onClick={loadCustomers}
            >
              刷新
            </Button>
          </Space>

          <Table<Customer>
            rowKey="id"

            columns={columns}

            dataSource={filteredCustomers}

            loading={loading}

            scroll={{
              x: 2200,
            }}

            pagination={{
              pageSize: 20,

              showSizeChanger: true,

              showTotal: (total) => `共 ${total} 位客户`,
            }}
          />
        </Card>
      </Space>

      {/* 登录记录 */}

      <Modal
        title={
          selectedCustomer
            ? `${selectedCustomer.fullName} - 登录记录`
            : "登录记录"
        }

        open={historyOpen}

        footer={null}

        onCancel={() => setHistoryOpen(false)}

        width={1000}
      >
        <Table<LoginAudit>
          rowKey={(record) =>
            record.id ?? `${record.createdAt}-${record.ipAddress}`
          }

          columns={[
            {
              title: "时间",

              dataIndex: "createdAt",

              render: (value) => formatDate(value),
            },

            {
              title: "IP",

              dataIndex: "ipAddress",
            },

            {
              title: "设备",

              dataIndex: "userAgent",

              render: (value) => getDeviceLabel(value),
            },

            {
              title: "结果",

              dataIndex: "success",

              render: (value) => (
                <Tag color={value ? "green" : "red"}>
                  {value ? "成功" : "失败"}
                </Tag>
              ),
            },
          ]}

          dataSource={loginHistory}

          loading={historyLoading}
        />
      </Modal>

      {/* 风险详情 */}

      <Modal
        title={
          selectedCustomer
            ? `${selectedCustomer.fullName} - 登录风险`
            : "风险详情"
        }

        open={riskOpen}

        footer={null}

        onCancel={() => setRiskOpen(false)}

        confirmLoading={riskLoading}
      >
        {selectedRisk && (
          <Space orientation="vertical" size="large" style={{ width: "100%" }}>
            <Space size="large" wrap>
              <Card>
                <Statistic
                  title="24小时失败登录"
                  value={selectedRisk.failedLoginCount24h}
                />
              </Card>

              <Card>
                <Statistic
                  title="风险等级"
                  value={riskTag(selectedRisk.riskLevel).text}
                />
              </Card>
            </Space>

            <Card title="最近失败登录">
              {selectedRisk.lastFailedLogin ? (
                <Space orientation="vertical">
                  <Text>
                    时间：
                    {formatDate(selectedRisk.lastFailedLogin.createdAt)}
                  </Text>

                  <Text>
                    IP：
                    {selectedRisk.lastFailedLogin.ipAddress || "-"}
                  </Text>

                  <Text>
                    设备：
                    {getDeviceLabel(selectedRisk.lastFailedLogin.userAgent)}
                  </Text>
                </Space>
              ) : (
                <Text type="secondary">暂无失败记录</Text>
              )}
            </Card>
          </Space>
        )}
      </Modal>

      <Modal
        title={sharedType === "IP" ? "共享 IP 风险" : "共享设备风险"}
        open={sharedOpen}
        footer={null}
        width={1100}
        onCancel={() => setSharedOpen(false)}
      >
        <Table<any>
          rowKey={sharedType === "IP" ? "ipAddress" : "userAgent"}

          dataSource={sharedType === "IP" ? sharedIpRisks : sharedDeviceRisks}

          columns={
            (sharedType === "IP"
              ? [
                  {
                    title: "IP地址",
                    dataIndex: "ipAddress",
                  },

                  {
                    title: "客户数量",
                    dataIndex: "customerCount",
                  },

                  {
                    title: "客户",

                    render: (_: any, record: SharedIpRisk) => (
                      <Space orientation="vertical">
                        {record.customers.map((customer) => (
                          <div key={customer.id}>
                            <Tag color="red">{customer.fullName}</Tag>

                            <Text type="secondary">
                              {customer.phone || "-"}
                            </Text>
                          </div>
                        ))}
                      </Space>
                    ),
                  },
                ]
              : [
                  {
                    title: "设备",

                    dataIndex: "userAgent",

                    render: (value: string) => getDeviceLabel(value),
                  },

                  {
                    title: "客户数量",

                    dataIndex: "customerCount",
                  },

                  {
                    title: "客户",

                    render: (_: any, record: SharedDeviceRisk) => (
                      <Space orientation="vertical">
                        {record.customers.map((customer) => (
                          <div key={customer.id}>
                            <Tag color="orange">{customer.fullName}</Tag>

                            <Text type="secondary">
                              {customer.phone || "-"}
                            </Text>
                          </div>
                        ))}
                      </Space>
                    ),
                  },
                ]) as any
          }
        />
      </Modal>
    </AdminShell>
  );
}
