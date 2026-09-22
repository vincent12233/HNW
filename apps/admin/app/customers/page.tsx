"use client";

import {
  HistoryOutlined,
  ProfileOutlined,
  ReloadOutlined,
  SafetyCertificateOutlined,
  SearchOutlined,
} from "@ant-design/icons";
import {
  Button,
  Descriptions,
  Input,
  Select,
  Space,
  Table,
  Tag,
  Tooltip,
  Typography,
  message,
} from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useRef, useState } from "react";

import AdminShell from "@/components/AdminShell";
import OpsDrawer from "@/components/OpsDrawer";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import { api, getApiErrorMessage } from "@/lib/api";
import { getBackendRole } from "@/lib/backend-role";
import {
  DIRECTORY_SCOPE_COPY,
  LOADED_FILTER_CAPTION,
  accountStatusLabel,
  filterLoadedRows,
  maskOpsPhone,
  useDebouncedValue,
} from "@/lib/ops-directory";
import { formatOpsDateTime, OPS_TABLE_PAGINATION } from "@/lib/ops-format";
import { vipTierLabel } from "@/lib/vip";

const { Paragraph, Text } = Typography;

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
  email?: string | null;
  role: string;
  status: string;
  createdAt: string;
  updatedAt?: string;
  account?: Account | null;
  assignedBusiness?: AssignedBusiness | null;
  loginAudits?: LoginAudit[];
  loginRisk?: LoginRisk | null;
};

type CustomerOverview = {
  customer: Customer;
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
    amount: string | number;
    orderNo?: string | null;
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

function getDeviceLabel(userAgent?: string | null) {
  if (!userAgent) return "—";
  const ua = userAgent.toLowerCase();
  let platform = "未知设备";
  let client = "未知客户端";
  if (ua.includes("android")) platform = "Android";
  else if (ua.includes("iphone") || ua.includes("ipad") || ua.includes("ios")) platform = "iOS";
  else if (ua.includes("windows")) platform = "Windows";
  else if (ua.includes("macintosh") || ua.includes("mac os")) platform = "macOS";
  else if (ua.includes("linux")) platform = "Linux";
  if (ua.includes("windowspowershell")) client = "PowerShell";
  else if (ua.includes("edg/")) client = "Edge";
  else if (ua.includes("chrome/")) client = "Chrome";
  else if (ua.includes("firefox/")) client = "Firefox";
  else if (ua.includes("safari/") && !ua.includes("chrome/")) client = "Safari";
  return `${platform} / ${client}`;
}

function riskCode(level?: string) {
  if (level === "HIGH") return { code: "HIGH", label: "高风险" };
  if (level === "MEDIUM") return { code: "PENDING", label: "注意" };
  if (level === "LOW") return { code: "ACTIVE", label: "正常" };
  return { code: "", label: "未获取" };
}

function Clip({ value }: { value?: string | null }) {
  const text = value?.trim() || "—";
  return (
    <span className="ops-cell-clip" title={text}>
      {text}
    </span>
  );
}

export default function CustomersPage() {
  const role = getBackendRole();
  const loadGen = useRef(0);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(false);
  const [keyword, setKeyword] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("ALL");
  const [tierFilter, setTierFilter] = useState<string>("ALL");
  const [businessFilter, setBusinessFilter] = useState<string>("ALL");
  const [error, setError] = useState("");
  const [detailError, setDetailError] = useState("");
  const debouncedKeyword = useDebouncedValue(keyword);

  const [historyOpen, setHistoryOpen] = useState(false);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [history, setHistory] = useState<LoginAudit[]>([]);

  const [riskOpen, setRiskOpen] = useState(false);
  const [riskLoading, setRiskLoading] = useState(false);
  const [selectedRisk, setSelectedRisk] = useState<LoginRisk | null>(null);

  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null);
  const [overviewOpen, setOverviewOpen] = useState(false);
  const [overviewLoading, setOverviewLoading] = useState(false);
  const [overview, setOverview] = useState<CustomerOverview | null>(null);

  async function loadCustomers() {
    const gen = ++loadGen.current;
    setLoading(true);
    setError("");
    try {
      const response = await api.get<Customer[]>("/admin/customers");
      if (gen !== loadGen.current) return;
      const customerList = Array.isArray(response.data) ? response.data : [];
      setCustomers(customerList);
    } catch (requestError: unknown) {
      if (gen !== loadGen.current) return;
      setError(getApiErrorMessage(requestError, "客户数据加载失败"));
      setCustomers([]);
    } finally {
      if (gen === loadGen.current) setLoading(false);
    }
  }

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const initialKeyword = params.get("keyword");
    if (initialKeyword) setKeyword(initialKeyword);
    void loadCustomers();
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
      message.error(getApiErrorMessage(requestError, "客户详情加载失败"));
    } finally {
      setOverviewLoading(false);
    }
  }

  async function openLoginHistory(customer: Customer) {
    setSelectedCustomer(customer);
    setHistoryOpen(true);
    setHistoryLoading(true);
    setHistory([]);
    setDetailError("");
    try {
      const response = await api.get<LoginAudit[]>(
        `/admin/customers/${customer.id}/login-audits`,
      );
      setHistory(Array.isArray(response.data) ? response.data : []);
    } catch (requestError: unknown) {
      setDetailError(getApiErrorMessage(requestError, "登录记录加载失败"));
    } finally {
      setHistoryLoading(false);
    }
  }

  async function openLoginRisk(customer: Customer) {
    setSelectedCustomer(customer);
    setRiskOpen(true);
    setRiskLoading(true);
    setSelectedRisk(null);
    setDetailError("");
    try {
      const response = await api.get<LoginRisk>(
        `/admin/customers/${customer.id}/login-risk`,
      );
      setSelectedRisk(response.data);
    } catch (requestError: unknown) {
      setDetailError(getApiErrorMessage(requestError, "登录风险数据加载失败"));
    } finally {
      setRiskLoading(false);
    }
  }

  const businessOptions = useMemo(() => {
    const map = new Map<string, string>();
    for (const customer of customers) {
      if (customer.assignedBusiness?.id) {
        map.set(customer.assignedBusiness.id, customer.assignedBusiness.fullName);
      }
    }
    return Array.from(map, ([value, label]) => ({ value, label }));
  }, [customers]);

  const filteredCustomers = useMemo(() => {
    return filterLoadedRows(
      customers.filter((customer) => {
        if (statusFilter !== "ALL" && customer.status !== statusFilter) return false;
        if (tierFilter !== "ALL" && (customer.clientTier || "STANDARD") !== tierFilter) {
          return false;
        }
        if (businessFilter !== "ALL" && customer.assignedBusiness?.id !== businessFilter) {
          return false;
        }
        return true;
      }),
      debouncedKeyword,
      (customer) => [
        customer.fullName,
        customer.customerNo,
        customer.id,
        maskOpsPhone(customer.phone, ""),
        customer.phone,
        customer.account?.accountNumber,
        customer.assignedBusiness?.fullName,
        customer.assignedBusiness?.businessProfile?.employeeNo,
        customer.clientTier,
      ],
    );
  }, [businessFilter, customers, debouncedKeyword, statusFilter, tierFilter]);

  const hasFilters =
    keyword.trim() !== "" ||
    statusFilter !== "ALL" ||
    tierFilter !== "ALL" ||
    businessFilter !== "ALL";

  function clearFilters() {
    setKeyword("");
    setStatusFilter("ALL");
    setTierFilter("ALL");
    setBusinessFilter("ALL");
  }

  const columns: ColumnsType<Customer> = [
    {
      title: "客户编号",
      dataIndex: "customerNo",
      key: "customerNo",
      width: 140,
      fixed: "left",
      render: (value: string | null | undefined, record) => (
        <span className="ops-id" title={record.id}>
          {value || record.id}
        </span>
      ),
    },
    {
      title: "客户名称",
      dataIndex: "fullName",
      key: "fullName",
      width: 180,
      render: (value: string) => <Clip value={value} />,
    },
    {
      title: "脱敏手机号",
      dataIndex: "phone",
      key: "phone",
      width: 140,
      render: (value?: string | null) => maskOpsPhone(value),
    },
    {
      title: "状态",
      dataIndex: "status",
      key: "status",
      width: 120,
      render: (status: string) => (
        <OpsStatusTag code={status} label={accountStatusLabel(status)} />
      ),
    },
    {
      title: "所属业务员",
      key: "business",
      width: 190,
      render: (_, record) =>
        record.assignedBusiness ? (
          <Space orientation="vertical" size={0}>
            <Clip value={record.assignedBusiness.fullName} />
            <Text type="secondary" style={{ fontSize: 12 }}>
              {record.assignedBusiness.businessProfile?.employeeNo || "—"}
            </Text>
          </Space>
        ) : (
          "—"
        ),
    },
    {
      title: "VIP",
      key: "clientTier",
      width: 150,
      render: (_, customer) => (
        <Tag aria-label={`VIP ${vipTierLabel(customer.clientTier)}`}>
          {vipTierLabel(customer.clientTier)}
        </Tag>
      ),
    },
    {
      title: "交易账号",
      key: "accountNumber",
      width: 170,
      render: (_, record) => (
        <span className="ops-id">{record.account?.accountNumber || "—"}</span>
      ),
    },
    {
      title: "现金余额",
      key: "cashBalance",
      width: 150,
      align: "right",
      render: (_, record) => <OpsMoney value={record.account?.cashBalance} />,
    },
    {
      title: "创建时间",
      dataIndex: "createdAt",
      key: "createdAt",
      width: 180,
      render: (value: string) => (
        <span className="ops-datetime">{formatOpsDateTime(value)}</span>
      ),
    },
    {
      title: "最近更新",
      dataIndex: "updatedAt",
      key: "updatedAt",
      width: 180,
      render: (value?: string) => (
        <span className="ops-datetime">{formatOpsDateTime(value)}</span>
      ),
    },
    {
      title: "操作",
      key: "actions",
      width: 280,
      fixed: "right",
      render: (_, record) => (
        <Space wrap>
          <Button
            size="small"
            type="primary"
            icon={<ProfileOutlined />}
            aria-label={`查看客户 ${record.fullName} 详情`}
            onClick={() => openOverview(record)}
          >
            客户详情
          </Button>
          <Tooltip title="登录记录">
            <Button
              size="small"
              icon={<HistoryOutlined />}
              aria-label={`查看客户 ${record.fullName} 登录记录`}
              onClick={() => openLoginHistory(record)}
            />
          </Tooltip>
          <Tooltip title="登录风险">
            <Button
              size="small"
              icon={<SafetyCertificateOutlined />}
              aria-label={`查看客户 ${record.fullName} 登录风险`}
              onClick={() => openLoginRisk(record)}
            />
          </Tooltip>
        </Space>
      ),
    },
  ];

  const historyColumns: ColumnsType<LoginAudit> = [
    {
      title: "登录时间",
      dataIndex: "createdAt",
      render: (value: string) => formatOpsDateTime(value),
    },
    {
      title: "IP地址",
      dataIndex: "ipAddress",
      render: (value) => value || "—",
    },
    {
      title: "设备",
      dataIndex: "userAgent",
      render: (value) => getDeviceLabel(value),
    },
    {
      title: "结果",
      dataIndex: "success",
      render: (success: boolean) => (
        <OpsStatusTag code={success ? "ACTIVE" : "FAILED"} label={success ? "成功" : "失败"} />
      ),
    },
  ];

  const selectedRiskSpec = riskCode(selectedRisk?.riskLevel);
  const scopeCopy =
    role === "FINANCE"
      ? DIRECTORY_SCOPE_COPY.financeCustomers
      : DIRECTORY_SCOPE_COPY.adminCustomers;

  return (
    <AdminShell>
      <div className="ops-directory-panel">
        <OpsPageHeader
          title="客户管理"
          crumbs={[{ title: "治理与人员" }, { title: "客户管理" }]}
          description={scopeCopy}
          extra={
            <Button
              icon={<ReloadOutlined />}
              aria-label="刷新客户列表"
              onClick={() => void loadCustomers()}
              loading={loading}
            >
              刷新
            </Button>
          }
        />

        {error ? (
          <OpsErrorState title={error} onRetry={() => void loadCustomers()} />
        ) : null}

        <OpsToolbar
          extra={
            hasFilters ? (
              <Button aria-label="清除筛选" onClick={clearFilters}>
                清除筛选
              </Button>
            ) : null
          }
        >
          <Input
            allowClear
            prefix={<SearchOutlined />}
            placeholder="搜索已加载的姓名、编号、脱敏手机号或业务员"
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            aria-label="搜索已加载客户"
            style={{ width: 360, maxWidth: "100%" }}
          />
          <Select
            aria-label="按账户状态筛选已加载结果"
            value={statusFilter}
            style={{ width: 140 }}
            onChange={setStatusFilter}
            options={[
              { value: "ALL", label: "全部状态" },
              { value: "ACTIVE", label: "正常" },
              { value: "SUSPENDED", label: "已暂停" },
              { value: "DISABLED", label: "已停用" },
            ]}
          />
          <Select
            aria-label="按 VIP 资料筛选已加载结果"
            value={tierFilter}
            style={{ width: 160 }}
            onChange={setTierFilter}
            options={[
              { value: "ALL", label: "全部 VIP" },
              { value: "STANDARD", label: "标准 Standard" },
              { value: "SILVER", label: "白银 Silver" },
              { value: "GOLD", label: "黄金 Gold" },
              { value: "PLATINUM", label: "铂金 Platinum" },
            ]}
          />
          <Select
            aria-label="按所属业务员筛选已加载结果"
            value={businessFilter}
            style={{ width: 180 }}
            onChange={setBusinessFilter}
            options={[{ value: "ALL", label: "全部业务员" }, ...businessOptions]}
          />
        </OpsToolbar>
        <p className="ops-loaded-filter-caption">
          {LOADED_FILTER_CAPTION} {DIRECTORY_SCOPE_COPY.noKycOnList}
        </p>

        <Table<Customer>
          rowKey="id"
          className="ops-directory-table"
          columns={columns}
          dataSource={filteredCustomers}
          loading={loading}
          tableLayout="fixed"
          scroll={{ x: 1980 }}
          pagination={{
            ...OPS_TABLE_PAGINATION,
            showTotal: (total) => `共 ${total} 位客户`,
          }}
          locale={{
            emptyText: loading ? (
              <OpsEmpty description="正在加载客户…" />
            ) : (
              <OpsEmpty
                description={
                  hasFilters ? "没有匹配的已加载结果" : "暂无客户记录"
                }
                onRetry={hasFilters ? undefined : () => void loadCustomers()}
              />
            ),
          }}
        />
      </div>

      <OpsDrawer
        title={selectedCustomer ? `${selectedCustomer.fullName} · 客户详情` : "客户详情"}
        open={overviewOpen}
        onClose={() => setOverviewOpen(false)}
        width={720}
      >
        {overviewLoading ? <Paragraph type="secondary">加载中…</Paragraph> : null}
        {!overviewLoading && overview ? (
          <>
            <Descriptions size="small" column={1} bordered>
              <Descriptions.Item label="客户编号">
                <span className="ops-id">
                  {overview.customer.customerNo || overview.customer.id}
                </span>
              </Descriptions.Item>
              <Descriptions.Item label="客户名称">
                <Clip value={overview.customer.fullName} />
              </Descriptions.Item>
              <Descriptions.Item label="脱敏手机号">
                {maskOpsPhone(overview.customer.phone)}
              </Descriptions.Item>
              <Descriptions.Item label="邮箱">
                <Clip value={overview.customer.email} />
              </Descriptions.Item>
              <Descriptions.Item label="客户状态">
                <OpsStatusTag
                  code={overview.customer.status}
                  label={accountStatusLabel(overview.customer.status)}
                />
              </Descriptions.Item>
              <Descriptions.Item label="KYC 状态">
                {overview.kyc?.status ? (
                  <OpsStatusTag code={overview.kyc.status} />
                ) : (
                  "当前详情未返回 KYC"
                )}
              </Descriptions.Item>
              <Descriptions.Item label="所属业务员">
                {overview.customer.assignedBusiness?.fullName || "—"}
              </Descriptions.Item>
              <Descriptions.Item label="VIP">
                <Tag aria-label={`VIP ${vipTierLabel(overview.customer.clientTier)}`}>
                  {vipTierLabel(overview.customer.clientTier)}
                </Tag>
              </Descriptions.Item>
              <Descriptions.Item label="交易账号">
                <span className="ops-id">
                  {overview.customer.account?.accountNumber || "—"}
                </span>
              </Descriptions.Item>
              <Descriptions.Item label="现金余额">
                <OpsMoney value={overview.customer.account?.cashBalance} />
              </Descriptions.Item>
              <Descriptions.Item label="可用资金">
                <OpsMoney value={overview.customer.account?.buyingPower} />
              </Descriptions.Item>
              <Descriptions.Item label="冻结资金">
                <OpsMoney value={overview.customer.account?.frozenBalance} />
              </Descriptions.Item>
              <Descriptions.Item label="创建时间">
                {formatOpsDateTime(overview.customer.createdAt)}
              </Descriptions.Item>
              <Descriptions.Item label="最近更新">
                {formatOpsDateTime(overview.customer.updatedAt)}
              </Descriptions.Item>
            </Descriptions>
            <div className="ops-drawer-section">
              <h3>最近入金</h3>
              <Table
                rowKey="id"
                size="small"
                pagination={false}
                dataSource={overview.recentDeposits ?? []}
                columns={[
                  {
                    title: "金额",
                    dataIndex: "amount",
                    render: (value) => <OpsMoney value={value} />,
                  },
                  {
                    title: "状态",
                    dataIndex: "status",
                    render: (value: string) => <OpsStatusTag code={value} />,
                  },
                  {
                    title: "时间",
                    dataIndex: "createdAt",
                    render: (value: string) => formatOpsDateTime(value),
                  },
                ]}
                locale={{ emptyText: "暂无入金记录" }}
              />
            </div>
            <div className="ops-drawer-section">
              <h3>最近提现</h3>
              <Table
                rowKey="id"
                size="small"
                pagination={false}
                dataSource={overview.recentWithdrawals ?? []}
                columns={[
                  {
                    title: "金额",
                    dataIndex: "amount",
                    render: (value) => <OpsMoney value={value} />,
                  },
                  {
                    title: "状态",
                    dataIndex: "status",
                    render: (value: string) => <OpsStatusTag code={value} />,
                  },
                  {
                    title: "时间",
                    dataIndex: "createdAt",
                    render: (value: string) => formatOpsDateTime(value),
                  },
                ]}
                locale={{ emptyText: "暂无提现记录" }}
              />
            </div>
            <div className="ops-drawer-section">
              <h3>最近订单</h3>
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
                        : "—",
                  },
                  {
                    title: "状态",
                    dataIndex: "status",
                    render: (value: string) => <OpsStatusTag code={value} />,
                  },
                  {
                    title: "时间",
                    dataIndex: "placedAt",
                    render: (value: string) => formatOpsDateTime(value),
                  },
                ]}
                locale={{ emptyText: "暂无订单记录" }}
              />
            </div>
          </>
        ) : null}
      </OpsDrawer>

      <OpsModal
        title={selectedCustomer ? `${selectedCustomer.fullName} - 登录记录` : "登录记录"}
        open={historyOpen}
        onCancel={() => setHistoryOpen(false)}
        footer={null}
        width={920}
      >
        {detailError && historyOpen ? <OpsErrorState title={detailError} /> : null}
        <Table<LoginAudit>
          rowKey={(record) =>
            record.id ?? `${record.createdAt}-${record.ipAddress ?? ""}`
          }
          columns={historyColumns}
          dataSource={history}
          loading={historyLoading}
          scroll={{ x: 720 }}
          pagination={OPS_TABLE_PAGINATION}
        />
      </OpsModal>

      <OpsModal
        title={selectedCustomer ? `${selectedCustomer.fullName} - 登录风险` : "登录风险"}
        open={riskOpen}
        onCancel={() => setRiskOpen(false)}
        footer={null}
        width={640}
        loading={riskLoading}
      >
        {detailError && riskOpen ? <OpsErrorState title={detailError} /> : null}
        {selectedRisk ? (
          <Descriptions size="small" column={1} bordered>
            <Descriptions.Item label="24小时失败登录">
              {selectedRisk.failedLoginCount24h}
            </Descriptions.Item>
            <Descriptions.Item label="风险等级">
              <OpsStatusTag code={selectedRiskSpec.code} label={selectedRiskSpec.label} />
            </Descriptions.Item>
            <Descriptions.Item label="最近失败登录">
              {selectedRisk.lastFailedLogin
                ? `${formatOpsDateTime(selectedRisk.lastFailedLogin.createdAt)} · ${selectedRisk.lastFailedLogin.ipAddress || "—"}`
                : "暂无失败登录记录"}
            </Descriptions.Item>
            <Descriptions.Item label="最近成功登录">
              {selectedRisk.lastSuccessfulLogin
                ? `${formatOpsDateTime(selectedRisk.lastSuccessfulLogin.createdAt)} · ${selectedRisk.lastSuccessfulLogin.ipAddress || "—"}`
                : "暂无成功登录记录"}
            </Descriptions.Item>
          </Descriptions>
        ) : null}
      </OpsModal>
    </AdminShell>
  );
}
