"use client";

import {
  HistoryOutlined,
  ProfileOutlined,
  ReloadOutlined,
  SafetyCertificateOutlined,
  SearchOutlined,
  CrownOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Descriptions,
  Drawer,
  Input,
  Select,
  message,
  Modal,
  Space,
  Statistic,
  Table,
  Tag,
  Typography,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import { api, getApiErrorMessage } from '@/lib/api';
import { getBackendRole } from "@/lib/backend-role";

const { Title, Paragraph, Text } = Typography;

type Account = {
  id: string;
  accountNumber: string;
  cashBalance: string | number;
  buyingPower: string | number;
  frozenBalance: string | number;
  currency: string;
  isLive: boolean;
};

type AssignedBusiness = {
  id: string;
  fullName: string;
  phone?: string | null;
  businessProfile?: {
    employeeNo?: string | null;
    department?: string | null;
  } | null;
};

type LoginAudit = {
  id?: string;
  userId?: string;
  ipAddress?: string | null;
  userAgent?: string | null;
  success: boolean;
  createdAt: string;
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

type Customer = {
  id: string;
  customerNo?: string | null;
  clientTier?: string | null;
  fullName: string;
  phone?: string | null;
  role: string;
  status: string;
  createdAt: string;
  account?: Account | null;
  assignedBusiness?: AssignedBusiness | null;
  loginAudits?: LoginAudit[];
  loginRisk?: LoginRisk | null;
};

type CustomerOverview = {
  customer: Customer & {
    email?: string | null;
  };
  kyc?: {
    id?: string;
    status: string;
    documentType?: string;
    reviewNote?: string | null;
    createdAt?: string;
  };
  recentDeposits?: Array<{
    id: string;
    amount: string | number;
    paymentMethod?: string | null;
    referenceId?: string | null;
    status: string;
    note?: string | null;
    createdAt: string;
  }>;
  recentWithdrawals?: Array<{
    id: string;
    orderNo?: string | null;
    amount: string | number;
    status: string;
    note?: string | null;
    createdAt: string;
  }>;
  recentOrders?: Array<{
    id: string;
    clientOrderId: string;
    side: string;
    type: string;
    status: string;
    quantity: number;
    filledQuantity: number;
    limitPrice?: string | number | null;
    averageFillPrice?: string | number | null;
    placedAt: string;
    instrument?: {
      symbol: string;
      name: string;
      exchange: string;
    } | null;
  }>;
};

function statusTag(status?: string) {
  const map: Record<string, { color: string; label: string }> = {
    PENDING: { color: "orange", label: "待处理" },
    APPROVED: { color: "green", label: "已通过" },
    REJECTED: { color: "red", label: "已拒绝" },
    NOT_SUBMITTED: { color: "default", label: "未提交" },
    FILLED: { color: "green", label: "已成交" },
    CANCELLED: { color: "default", label: "已取消" },
    OPEN: { color: "blue", label: "挂单中" },
    PARTIALLY_FILLED: { color: "blue", label: "部分成交" },
  };
  const config = map[status ?? ""] ?? { color: "default", label: status || "-" };
  return <Tag color={config.color}>{config.label}</Tag>;
}

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
  let client = "未知客户端";

  if (ua.includes("android")) {
    platform = "Android";
  } else if (
    ua.includes("iphone") ||
    ua.includes("ipad") ||
    ua.includes("ios")
  ) {
    platform = "iOS";
  } else if (ua.includes("windows")) {
    platform = "Windows";
  } else if (ua.includes("macintosh") || ua.includes("mac os")) {
    platform = "macOS";
  } else if (ua.includes("linux")) {
    platform = "Linux";
  }

  if (ua.includes("windowspowershell")) {
    client = "PowerShell";
  } else if (ua.includes("edg/")) {
    client = "Edge";
  } else if (ua.includes("chrome/")) {
    client = "Chrome";
  } else if (ua.includes("firefox/")) {
    client = "Firefox";
  } else if (ua.includes("safari/") && !ua.includes("chrome/")) {
    client = "Safari";
  }

  return `${platform} / ${client}`;
}

function getRiskConfig(riskLevel?: string) {
  if (riskLevel === "HIGH") {
    return {
      color: "red",
      label: "高风险",
    };
  }

  if (riskLevel === "MEDIUM") {
    return {
      color: "orange",
      label: "注意",
    };
  }

  return {
    color: "green",
    label: "正常",
  };
}

export default function CustomersPage() {
  const [tierSaving, setTierSaving] = useState<string | null>(null);
  const [tierCustomer, setTierCustomer] = useState<Customer | null>(null);
  const [tier, setTier] = useState('STANDARD');
  const tiers = [
    { value: 'STANDARD', label: '标准 Standard' },
    { value: 'SILVER', label: '白银 Silver' },
    { value: 'GOLD', label: '黄金 Gold' },
    { value: 'PLATINUM', label: '铂金 Platinum' },
  ];
  async function saveTier() {
    if (!tierCustomer || tierSaving) return;
    setTierSaving(tierCustomer.id);
    try {
      const { data } = await api.patch<{ id: string; clientTier: string }>(
        `/admin/clients/${tierCustomer.id}/tier`, { tier },
      );
      setCustomers(current => current.map(customer => customer.id === data.id
        ? { ...customer, clientTier: data.clientTier } : customer));
      setTierCustomer(null);
      message.success('会员等级已保存，客户重新进入个人资料页后同步');
    } catch {
      message.error('会员等级保存失败，请重试');
    } finally { setTierSaving(null); }
  }
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(false);
  const [keyword, setKeyword] = useState("");
  const [error, setError] = useState("");

  const [historyOpen, setHistoryOpen] = useState(false);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [history, setHistory] = useState<LoginAudit[]>([]);

  const [riskOpen, setRiskOpen] = useState(false);
  const [riskLoading, setRiskLoading] = useState(false);
  const [selectedRisk, setSelectedRisk] = useState<LoginRisk | null>(null);

  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(
    null,
  );

  const [overviewOpen, setOverviewOpen] = useState(false);
  const [overviewLoading, setOverviewLoading] = useState(false);
  const [overview, setOverview] = useState<CustomerOverview | null>(null);

  async function loadCustomers() {
    setLoading(true);
    setError("");

    try {
      const response = await api.get<Customer[]>("/admin/customers");

      const customerList = Array.isArray(response.data) ? response.data : [];

      const riskResults = await Promise.allSettled(
        customerList.map((customer) =>
          api.get<LoginRisk>(`/admin/customers/${customer.id}/login-risk`),
        ),
      );

      setCustomers(
        customerList.map((customer, index) => {
          const result = riskResults[index];

          return {
            ...customer,
            loginRisk: result.status === "fulfilled" ? result.value.data : null,
          };
        }),
      );
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "客户数据加载失败"));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const initialKeyword = params.get("keyword");

    if (initialKeyword) {
      setKeyword(initialKeyword);
    }

    loadCustomers();
  }, []);

  async function openOverview(customer: Customer) {
    setSelectedCustomer(customer);
    setOverviewOpen(true);
    setOverviewLoading(true);
    setOverview(null);

    try {
      const response = await api.get<CustomerOverview>(
        `/admin/customers/${customer.id}/overview`,
      );
      setOverview(response.data);
    } catch (requestError: unknown) {
      const responseMessage = getApiErrorMessage(requestError, "");
      message.error(responseMessage || "客户详情加载失败",
      );
    } finally {
      setOverviewLoading(false);
    }
  }

  async function openLoginHistory(customer: Customer) {
    setSelectedCustomer(customer);
    setHistoryOpen(true);
    setHistoryLoading(true);
    setHistory([]);

    try {
      const response = await api.get<LoginAudit[]>(
        `/admin/customers/${customer.id}/login-audits`,
      );

      setHistory(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "登录记录加载失败"));
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
        `/admin/customers/${customer.id}/login-risk`,
      );

      setSelectedRisk(response.data);
    } catch (requestError: unknown) {
      setError(getApiErrorMessage(requestError, "登录风险数据加载失败"));
    } finally {
      setRiskLoading(false);
    }
  }

  const filteredCustomers = useMemo(() => {
    const normalizedKeyword = keyword.trim().toLowerCase();

    if (!normalizedKeyword) {
      return customers;
    }

    return customers.filter((customer) => {
      const lastLogin = customer.loginAudits?.[0];

      const values = [
        customer.fullName,
        customer.customerNo,
        customer.phone,
        customer.account?.accountNumber,
        customer.assignedBusiness?.fullName,
        customer.assignedBusiness?.businessProfile?.employeeNo,
        lastLogin?.ipAddress,
        lastLogin?.userAgent,
        customer.loginRisk?.riskLevel,
      ];

      return values.some((value) =>
        String(value ?? "")
          .toLowerCase()
          .includes(normalizedKeyword),
      );
    });
  }, [customers, keyword]);

  const columns: ColumnsType<Customer> = [
    {
      title: '会员等级', key: 'clientTier', width: 180,
      render: (_, customer) => <Space direction="vertical" size={4}>
        <Tag icon={<CrownOutlined />} color={customer.clientTier === 'GOLD' ? 'gold' : 'blue'}>
          {tiers.find(item => item.value === customer.clientTier)?.label ?? '未设置'}
        </Tag>
        {getBackendRole() === 'ADMIN' && <Button size="small" type="link" onClick={() => {
          setTierCustomer(customer); setTier(customer.clientTier ?? 'STANDARD');
        }}>修改等级</Button>}
      </Space>,
    },
    {
      title: "客户姓名",
      dataIndex: "fullName",
      key: "fullName",
      width: 160,
      fixed: "left",
    },
    {
      title: "客户编号",
      dataIndex: "customerNo",
      key: "customerNo",
      width: 140,
      render: (value) => value || "-",
    },
    {
      title: "手机号",
      dataIndex: "phone",
      key: "phone",
      width: 140,
      render: (value) => (value ? `+91 ${value}` : "-"),
    },
    {
      title: "交易账号",
      key: "accountNumber",
      width: 170,
      render: (_, record) => record.account?.accountNumber || "-",
    },
    {
      title: "所属业务员",
      key: "business",
      width: 190,
      render: (_, record) =>
        record.assignedBusiness ? (
          <Space orientation="vertical" size={0}>
            <Text>{record.assignedBusiness.fullName}</Text>
            <Text type="secondary" style={{ fontSize: 12 }}>
              {record.assignedBusiness.businessProfile?.employeeNo || "-"}
            </Text>
          </Space>
        ) : (
          "-"
        ),
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
      title: "冻结资金",
      key: "frozenBalance",
      width: 150,
      align: "right",
      render: (_, record) => formatMoney(record.account?.frozenBalance),
    },
    {
      title: "最近登录IP",
      key: "lastLoginIp",
      width: 170,
      render: (_, record) => record.loginAudits?.[0]?.ipAddress || "-",
    },
    {
      title: "最近登录时间",
      key: "lastLoginTime",
      width: 190,
      render: (_, record) => formatDate(record.loginAudits?.[0]?.createdAt),
    },
    {
      title: "登录设备",
      key: "device",
      width: 180,
      render: (_, record) => getDeviceLabel(record.loginAudits?.[0]?.userAgent),
    },
    {
      title: "24小时失败",
      key: "failedLoginCount24h",
      width: 120,
      align: "center",
      render: (_, record) => {
        const count = record.loginRisk?.failedLoginCount24h ?? 0;

        return <Tag color={count > 0 ? "orange" : "green"}>{count}</Tag>;
      },
    },
    {
      title: "登录风险",
      key: "loginRisk",
      width: 120,
      render: (_, record) => {
        const config = getRiskConfig(record.loginRisk?.riskLevel);

        return <Tag color={config.color}>{config.label}</Tag>;
      },
    },
    {
      title: "状态",
      dataIndex: "status",
      key: "status",
      width: 110,
      render: (status: string) => (
        <Tag color={status === "ACTIVE" ? "green" : "red"}>
          {status === "ACTIVE" ? "正常" : "已停用"}
        </Tag>
      ),
    },
    {
      title: "注册时间",
      dataIndex: "createdAt",
      key: "createdAt",
      width: 180,
      render: (value: string) => formatDate(value),
    },
    {
      title: "操作",
      key: "actions",
      width: 340,
      fixed: "right",
      render: (_, record) => (
        <Space wrap>
          <Button
            size="small"
            type="primary"
            icon={<ProfileOutlined />}
            onClick={() => openOverview(record)}
          >
            客户详情
          </Button>

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
            风险详情
          </Button>
        </Space>
      ),
    },
  ];

  const historyColumns: ColumnsType<LoginAudit> = [
    {
      title: "登录时间",
      dataIndex: "createdAt",
      key: "createdAt",
      width: 190,
      render: (value: string) => formatDate(value),
    },
    {
      title: "IP地址",
      dataIndex: "ipAddress",
      key: "ipAddress",
      width: 180,
      render: (value) => value || "-",
    },
    {
      title: "设备",
      dataIndex: "userAgent",
      key: "device",
      width: 180,
      render: (value) => getDeviceLabel(value),
    },
    {
      title: "User-Agent",
      dataIndex: "userAgent",
      key: "userAgent",
      ellipsis: true,
      render: (value) => value || "-",
    },
    {
      title: "结果",
      dataIndex: "success",
      key: "success",
      width: 100,
      render: (success: boolean) => (
        <Tag color={success ? "green" : "red"}>{success ? "成功" : "失败"}</Tag>
      ),
    },
  ];

  const selectedRiskConfig = getRiskConfig(selectedRisk?.riskLevel);

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={2}>客户管理</Title>
          <Paragraph type="secondary">
            查看客户账户、所属业务员、余额以及登录安全风险。
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
              placeholder="搜索姓名、客户编号、手机号、交易账号、业务员或 IP"
              value={keyword}
              onChange={(event) => setKeyword(event.target.value)}
              style={{ width: 440 }}
            />

            <Button
              icon={<ReloadOutlined />}
              onClick={loadCustomers}
              loading={loading}
            >
              刷新
            </Button>
          </Space>

          <Table<Customer>
            rowKey="id"
            columns={columns}
            dataSource={filteredCustomers}
            loading={loading}
            scroll={{ x: 2500 }}
            pagination={{
              pageSize: 20,
              showSizeChanger: true,
              showTotal: (total) => `共 ${total} 位客户`,
            }}
          />
        </Card>
      </Space>

      <Drawer
        title={
          selectedCustomer
            ? `${selectedCustomer.fullName} · 客户详情`
            : "客户详情"
        }
        open={overviewOpen}
        onClose={() => setOverviewOpen(false)}
        width={920}
        destroyOnHidden
      >
        {overviewLoading && <Paragraph type="secondary">加载中…</Paragraph>}
        {!overviewLoading && overview && (
          <Space orientation="vertical" size="large" style={{ width: "100%" }}>
            <Descriptions size="small" column={2} bordered>
              <Descriptions.Item label="客户编号">
                {overview.customer.customerNo || "-"}
              </Descriptions.Item>
              <Descriptions.Item label="手机号">
                {overview.customer.phone ? `+91 ${overview.customer.phone}` : "-"}
              </Descriptions.Item>
              <Descriptions.Item label="邮箱">
                {overview.customer.email || "-"}
              </Descriptions.Item>
              <Descriptions.Item label="状态">
                <Tag color={overview.customer.status === "ACTIVE" ? "green" : "red"}>
                  {overview.customer.status === "ACTIVE" ? "正常" : "已停用"}
                </Tag>
              </Descriptions.Item>
              <Descriptions.Item label="交易账号">
                {overview.customer.account?.accountNumber || "-"}
              </Descriptions.Item>
              <Descriptions.Item label="KYC">
                {statusTag(overview.kyc?.status)}
              </Descriptions.Item>
              <Descriptions.Item label="现金余额">
                {formatMoney(overview.customer.account?.cashBalance)}
              </Descriptions.Item>
              <Descriptions.Item label="可用资金">
                {formatMoney(overview.customer.account?.buyingPower)}
              </Descriptions.Item>
              <Descriptions.Item label="冻结资金">
                {formatMoney(overview.customer.account?.frozenBalance)}
              </Descriptions.Item>
              <Descriptions.Item label="所属业务员">
                {overview.customer.assignedBusiness?.fullName || "-"}
              </Descriptions.Item>
            </Descriptions>

            <Card size="small" title="最近入金（最多 20 笔）">
              <Table
                rowKey="id"
                size="small"
                pagination={false}
                dataSource={overview.recentDeposits ?? []}
                columns={[
                  { title: "金额", dataIndex: "amount", render: formatMoney, width: 120 },
                  { title: "状态", dataIndex: "status", render: statusTag, width: 100 },
                  { title: "流水号", dataIndex: "referenceId", render: (v) => v || "-" },
                  { title: "时间", dataIndex: "createdAt", render: formatDate, width: 170 },
                ]}
                locale={{ emptyText: "暂无入金记录" }}
              />
            </Card>

            <Card size="small" title="最近提现（最多 20 笔）">
              <Table
                rowKey="id"
                size="small"
                pagination={false}
                dataSource={overview.recentWithdrawals ?? []}
                columns={[
                  { title: "订单号", dataIndex: "orderNo", render: (v) => v || "-", width: 160 },
                  { title: "金额", dataIndex: "amount", render: formatMoney, width: 120 },
                  { title: "状态", dataIndex: "status", render: statusTag, width: 100 },
                  { title: "时间", dataIndex: "createdAt", render: formatDate, width: 170 },
                ]}
                locale={{ emptyText: "暂无提现记录" }}
              />
            </Card>

            <Card size="small" title="最近订单（最多 20 笔）">
              <Table
                rowKey="id"
                size="small"
                pagination={false}
                dataSource={overview.recentOrders ?? []}
                columns={[
                  {
                    title: "标的",
                    render: (_, row) =>
                      row.instrument
                        ? `${row.instrument.symbol} · ${row.instrument.name}`
                        : "-",
                  },
                  { title: "方向", dataIndex: "side", width: 80 },
                  { title: "状态", dataIndex: "status", render: statusTag, width: 110 },
                  {
                    title: "数量",
                    width: 110,
                    render: (_, row) => `${row.filledQuantity}/${row.quantity}`,
                  },
                  { title: "时间", dataIndex: "placedAt", render: formatDate, width: 170 },
                ]}
                locale={{ emptyText: "暂无订单记录" }}
              />
            </Card>
          </Space>
        )}
      </Drawer>

      <Modal title="修改会员等级" open={tierCustomer !== null}
        closable={tierSaving === null} maskClosable={tierSaving === null} keyboard={tierSaving === null}
        onCancel={() => { if (!tierSaving) setTierCustomer(null); }}
        onOk={saveTier} confirmLoading={tierSaving !== null}
        cancelButtonProps={{ disabled: tierSaving !== null }} okText="保存" cancelText="取消">
        <Paragraph>{tierCustomer?.fullName} · {tierCustomer?.customerNo}</Paragraph>
        <Select aria-label="会员等级" style={{ width: '100%' }} value={tier}
          options={tiers} onChange={setTier} disabled={tierSaving !== null} />
      </Modal>
      <Modal
        title={
          selectedCustomer
            ? `${selectedCustomer.fullName} - 登录记录`
            : "登录记录"
        }
        open={historyOpen}
        onCancel={() => setHistoryOpen(false)}
        footer={null}
        width={1000}
      >
        <Table<LoginAudit>
          rowKey={(record) =>
            record.id ?? `${record.createdAt}-${record.ipAddress ?? ""}`
          }
          columns={historyColumns}
          dataSource={history}
          loading={historyLoading}
          scroll={{ x: 900 }}
          pagination={{
            pageSize: 10,
            showSizeChanger: true,
            showTotal: (total) => `共 ${total} 条登录记录`,
          }}
        />
      </Modal>

      <Modal
        title={
          selectedCustomer
            ? `${selectedCustomer.fullName} - 登录风险`
            : "登录风险"
        }
        open={riskOpen}
        onCancel={() => setRiskOpen(false)}
        footer={null}
        width={720}
        loading={riskLoading}
      >
        {selectedRisk && (
          <Space orientation="vertical" size="large" style={{ width: "100%" }}>
            <Space size="large" wrap>
              <Card size="small">
                <Statistic
                  title="24小时失败登录"
                  value={selectedRisk.failedLoginCount24h}
                />
              </Card>

              <Card size="small">
                <Statistic title="风险等级" value={selectedRiskConfig.label} />
              </Card>
            </Space>

            <Card size="small" title="最近失败登录">
              {selectedRisk.lastFailedLogin ? (
                <Space orientation="vertical" size="small">
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
                <Text type="secondary">暂无失败登录记录</Text>
              )}
            </Card>

            <Card size="small" title="最近成功登录">
              {selectedRisk.lastSuccessfulLogin ? (
                <Space orientation="vertical" size="small">
                  <Text>
                    时间：
                    {formatDate(selectedRisk.lastSuccessfulLogin.createdAt)}
                  </Text>
                  <Text>
                    IP：
                    {selectedRisk.lastSuccessfulLogin.ipAddress || "-"}
                  </Text>
                  <Text>
                    设备：
                    {getDeviceLabel(selectedRisk.lastSuccessfulLogin.userAgent)}
                  </Text>
                </Space>
              ) : (
                <Text type="secondary">暂无成功登录记录</Text>
              )}
            </Card>
          </Space>
        )}
      </Modal>
    </AdminShell>
  );
}
