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
} from "antd";

import type { ColumnsType } from "antd/es/table";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { isAxiosError } from "axios";

import AdminShell from "@/components/AdminShell";
import OpsDrawer from "@/components/OpsDrawer";
import OpsEmpty from "@/components/OpsEmpty";
import OpsErrorState from "@/components/OpsErrorState";
import OpsModal from "@/components/OpsModal";
import OpsMoney from "@/components/OpsMoney";
import OpsPageHeader from "@/components/OpsPageHeader";
import OpsStatusTag from "@/components/OpsStatusTag";
import OpsToolbar from "@/components/OpsToolbar";
import ScopedEditButton from "@/components/ScopedEditButton";
import { getBackendRole } from "@/lib/backend-role";
import { api } from "@/lib/api";
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

const { Text } = Typography;

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

  isLive: boolean;
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
  clientTier?: string;
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

function formatDate(value?: string | null) {
  return formatOpsDateTime(value);
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
  if (!level || !["LOW", "MEDIUM", "HIGH"].includes(level)) {
    return { color: "default", text: "未获取" };
  }
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
  const detailRequest = useRef(0);
  const listRequest = useRef(0);
  const [detailError, setDetailError] = useState("");
  const [customers, setCustomers] = useState<Customer[]>([]);

  const [keyword, setKeyword] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [tierFilter, setTierFilter] = useState("ALL");
  const [detailOpen, setDetailOpen] = useState(false);
  const debouncedKeyword = useDebouncedValue(keyword);

  const [loading, setLoading] = useState(false);

  const [error, setError] = useState("");

  const [sharedIpRisks, setSharedIpRisks] = useState<SharedIpRisk[]>([]);
  const [sharedIpReady, setSharedIpReady] = useState(false);
  const [sharedDeviceReady, setSharedDeviceReady] = useState(false);

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

  const loadCustomers = useCallback(async () => {
    const request = ++listRequest.current;
    setLoading(true);

    setError("");
    setSharedIpReady(false);
    setSharedDeviceReady(false);

    try {
      const customerResponse = await api.get<Customer[]>(
        "/business/my-customers",
      );
      if (request !== listRequest.current) return;

      if (!Array.isArray(customerResponse.data)) throw new Error("Invalid customer list");
      const list = customerResponse.data;
      setCustomers(list);
      setLoading(false);

      const [ipResponse, deviceResponse] = await Promise.allSettled([
        api.get<SharedIpRisk[]>("/business/shared-ip-risks"),

        api.get<SharedDeviceRisk[]>("/business/shared-device-risks"),
      ]);
      if (request !== listRequest.current) return;

      const ipAvailable = ipResponse.status === "fulfilled" && Array.isArray(ipResponse.value.data);
      const deviceAvailable = deviceResponse.status === "fulfilled" && Array.isArray(deviceResponse.value.data);
      setSharedIpReady(ipAvailable);
      setSharedDeviceReady(deviceAvailable);
      setSharedIpRisks(ipAvailable && ipResponse.status === "fulfilled" ? ipResponse.value.data : []);

      setSharedDeviceRisks(
        deviceAvailable && deviceResponse.status === "fulfilled" ? deviceResponse.value.data : [],
      );

      if (!ipAvailable || !deviceAvailable) {
        setError("客户列表已加载，部分风险信息获取失败；风险结果不完整，请刷新重试");
      }
    } catch (error: unknown) {
      if (request !== listRequest.current) return;
      const message = isAxiosError<{ message?: string | string[] }>(error)
        ? error.response?.data?.message : undefined;

      setError(
        Array.isArray(message)
          ? message.join("，")
          : message || "客户数据加载失败",
      );
    } finally {
      if (request === listRequest.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    const requestState = detailRequest;
    const listState = listRequest;
    const initialLoad = window.setTimeout(() => { void loadCustomers(); }, 0);
    return () => {
      window.clearTimeout(initialLoad);
      requestState.current++;
      listState.current++;
    };
  }, [loadCustomers]);

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
    const request = ++detailRequest.current;
    setRiskOpen(false);
    setDetailError("");
    setLoginHistory([]);
    setSelectedCustomer(customer);

    setHistoryOpen(true);

    setHistoryLoading(true);

    try {
      const response = await api.get<LoginAudit[]>(
        `/business/customers/${customer.id}/login-audits`,
      );

      if (request !== detailRequest.current) return;
      if (!Array.isArray(response.data)) throw new Error("Invalid login history");
      setLoginHistory(response.data);
    } catch {
      if (request === detailRequest.current) setDetailError("登录记录加载失败，请重试");
    } finally {
      if (request === detailRequest.current) setHistoryLoading(false);
    }
  }

  async function openLoginRisk(customer: Customer) {
    const request = ++detailRequest.current;
    setHistoryOpen(false);
    setDetailError("");
    setSelectedCustomer(customer);

    setRiskOpen(true);

    setRiskLoading(true);

    setSelectedRisk(null);

    try {
      const response = await api.get<LoginRisk>(
        `/business/customers/${customer.id}/login-risk`,
      );

      if (request !== detailRequest.current) return;
      if (response.data?.customer?.id !== customer.id) throw new Error("Invalid risk customer");
      setSelectedRisk(response.data);
    } catch {
      if (request === detailRequest.current) setDetailError("登录风险加载失败，请重试");
    } finally {
      if (request === detailRequest.current) setRiskLoading(false);
    }
  }

  function openShared(type: "IP" | "DEVICE") {
    setSharedType(type);

    setSharedOpen(true);
  }

  const filteredCustomers = useMemo(() => {
    return filterLoadedRows(
      customers.filter((customer) => {
        if (statusFilter !== "ALL" && customer.status !== statusFilter) return false;
        if (tierFilter !== "ALL" && (customer.clientTier || "STANDARD") !== tierFilter) {
          return false;
        }
        return true;
      }),
      debouncedKeyword,
      (customer) => [
        customer.fullName,
        customer.customerNo,
        customer.id,
        customer.phone,
        maskOpsPhone(customer.phone, ""),
        customer.account?.accountNumber,
        customer.usedInviteCode?.code,
        customer.clientTier,
        customer.loginRisk?.riskLevel,
      ],
    );
  }, [customers, debouncedKeyword, statusFilter, tierFilter]);
  const hasFilters =
    keyword.trim() !== "" || statusFilter !== "ALL" || tierFilter !== "ALL";

  const role = getBackendRole();
  const scopeCopy =
    role === "SUPPORT"
      ? DIRECTORY_SCOPE_COPY.supportCustomers
      : DIRECTORY_SCOPE_COPY.businessCustomers;

  const columns: ColumnsType<Customer> = [
    {
      title: "客户编号",
      dataIndex: "customerNo",
      width: 140,
      fixed: "left",
      render: (value, record) => (
        <span className="ops-id">{value || record.id}</span>
      ),
    },
    {
      title: "客户名称",
      dataIndex: "fullName",
      width: 180,
      render: (value: string) => (
        <span className="ops-cell-clip" title={value}>{value}</span>
      ),
    },
    {
      title: "脱敏手机号",
      dataIndex: "phone",
      width: 140,
      render: (value?: string | null) => maskOpsPhone(value),
    },
    {
      title: "状态",
      dataIndex: "status",
      width: 120,
      render: (value: string) => (
        <OpsStatusTag code={value} label={accountStatusLabel(value)} />
      ),
    },
    {
      title: "VIP",
      width: 150,
      render: (_, record) => (
        <Tag aria-label={`VIP ${vipTierLabel(record.clientTier)}`}>
          {vipTierLabel(record.clientTier)}
        </Tag>
      ),
    },
    {
      title: "交易账号",
      width: 170,
      render: (_, record) => (
        <span className="ops-id">{record.account?.accountNumber || "—"}</span>
      ),
    },
    {
      title: "现金余额",
      width: 150,
      align: "right",
      render: (_, record) => <OpsMoney value={record.account?.cashBalance} />,
    },
    {
      title: "创建时间",
      dataIndex: "createdAt",
      width: 180,
      render: (value: string) => formatOpsDateTime(value),
    },
    {
      title: "登录风险",
      width: 120,
      render: () => <OpsStatusTag code="" label="详情查看" />,
    },
    {
      title: "共享IP",
      width: 120,
      render: (_, record) =>
        !sharedIpReady ? (
          <OpsStatusTag label="未获取" />
        ) : customerHasSharedIp(record.id) ? (
          <OpsStatusTag code="FAILED" label="共享IP" />
        ) : (
          <OpsStatusTag code="ACTIVE" label="正常" />
        ),
    },
    {
      title: "共享设备",
      width: 130,
      render: (_, record) =>
        !sharedDeviceReady ? (
          <OpsStatusTag label="未获取" />
        ) : customerHasSharedDevice(record.id) ? (
          <OpsStatusTag code="PENDING" label="共享设备" />
        ) : (
          <OpsStatusTag code="ACTIVE" label="正常" />
        ),
    },
    {
      title: "操作",
      width: 280,
      fixed: "right",
      render: (_, record) => (
        <Space wrap>
          <Button
            size="small"
            type="primary"
            icon={<ProfileOutlined />}
            aria-label={`查看客户 ${record.fullName} 详情`}
            onClick={() => {
              setSelectedCustomer(record);
              setDetailOpen(true);
            }}
          >
            详情
          </Button>
          <ScopedEditButton
            name={record.fullName}
            current={record.status}
            kind="status"
            endpoint={`/business/customers/${record.id}/status`}
            onSaved={loadCustomers}
          />
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

  return (
    <AdminShell>
      <div className="ops-directory-panel">
        <OpsPageHeader
          title="我的客户"
          crumbs={[{ title: "我的客户" }, { title: "客户列表" }]}
          description={scopeCopy}
          extra={
            <Button
              icon={<ReloadOutlined />}
              aria-label="刷新客户列表"
              loading={loading}
              onClick={loadCustomers}
            >
              刷新
            </Button>
          }
        />
        {error ? <OpsErrorState title={error} onRetry={loadCustomers} /> : null}
        <div className="ops-stat-strip">
          <div className="ops-stat-pill">
            <span className="label">客户数量</span>
            <strong className="value">{customers.length}</strong>
          </div>
          <button
            type="button"
            className="ops-stat-pill"
            onClick={() => openShared("IP")}
            aria-label="查看共享 IP 风险"
          >
            <span className="label">共享IP风险客户</span>
            <strong className="value">
              {!sharedIpReady
                ? "—"
                : new Set(sharedIpRisks.flatMap((item) => item.customers.map((c) => c.id))).size}
            </strong>
          </button>
          <button
            type="button"
            className="ops-stat-pill"
            onClick={() => openShared("DEVICE")}
            aria-label="查看共享设备风险"
          >
            <span className="label">共享设备风险客户</span>
            <strong className="value">
              {!sharedDeviceReady
                ? "—"
                : new Set(sharedDeviceRisks.flatMap((item) => item.customers.map((c) => c.id))).size}
            </strong>
          </button>
        </div>
        <OpsToolbar
          extra={
            hasFilters ? (
              <Button
                aria-label="清除筛选"
                onClick={() => {
                  setKeyword("");
                  setStatusFilter("ALL");
                  setTierFilter("ALL");
                }}
              >
                清除筛选
              </Button>
            ) : null
          }
        >
          <Input
            allowClear
            prefix={<SearchOutlined />}
            placeholder="搜索已加载的姓名、编号或脱敏手机号"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
            aria-label="搜索已加载客户"
            style={{ width: 320, maxWidth: "100%" }}
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
            emptyText: (
              <OpsEmpty
                description={hasFilters ? "没有匹配的已加载结果" : "暂无客户记录"}
                onRetry={hasFilters ? undefined : loadCustomers}
              />
            ),
          }}
        />
      </div>

      <OpsDrawer
        title={selectedCustomer ? `${selectedCustomer.fullName} · 客户详情` : "客户详情"}
        open={detailOpen}
        onClose={() => setDetailOpen(false)}
        width={480}
      >
        {selectedCustomer ? (
          <>
          <Descriptions size="small" column={1} bordered>
            <Descriptions.Item label="客户编号">
              <span className="ops-id">{selectedCustomer.customerNo || selectedCustomer.id}</span>
            </Descriptions.Item>
            <Descriptions.Item label="客户名称">
              <span className="ops-cell-clip" title={selectedCustomer.fullName}>
                {selectedCustomer.fullName}
              </span>
            </Descriptions.Item>
            <Descriptions.Item label="脱敏手机号">
              {maskOpsPhone(selectedCustomer.phone)}
            </Descriptions.Item>
            <Descriptions.Item label="客户状态">
              <OpsStatusTag
                code={selectedCustomer.status}
                label={accountStatusLabel(selectedCustomer.status)}
              />
            </Descriptions.Item>
            <Descriptions.Item label="VIP">
              <Tag aria-label={`VIP ${vipTierLabel(selectedCustomer.clientTier)}`}>
                {vipTierLabel(selectedCustomer.clientTier)}
              </Tag>
            </Descriptions.Item>
            <Descriptions.Item label="交易账号">
              <span className="ops-id">{selectedCustomer.account?.accountNumber || "—"}</span>
            </Descriptions.Item>
            <Descriptions.Item label="现金余额">
              <OpsMoney value={selectedCustomer.account?.cashBalance} />
            </Descriptions.Item>
            <Descriptions.Item label="可用资金">
              <OpsMoney value={selectedCustomer.account?.buyingPower} />
            </Descriptions.Item>
            <Descriptions.Item label="创建时间">
              {formatOpsDateTime(selectedCustomer.createdAt)}
            </Descriptions.Item>
            <Descriptions.Item label="KYC 状态">
              当前客户列表接口未返回 KYC，不在本页伪装审核入口。
            </Descriptions.Item>
          </Descriptions>
          <div className="ops-drawer-section">
            <h3>相关业务模块</h3>
            <Typography.Paragraph type="secondary">以下入口打开模块列表，不会自动按当前客户筛选，请在目标页面核对客户和账号。</Typography.Paragraph>
            <Space wrap>
              <Button href="/business-orders">订单模块</Button>
              <Button href="/business-trades">成交模块</Button>
              <Button href="/business-deposits">入金模块</Button>
              <Button href="/business-withdrawals">提现模块</Button>
              <Button href="/business-positions">持仓模块</Button>
            </Space>
          </div>
          </>
        ) : null}
      </OpsDrawer>

      <OpsModal
        title={
          selectedCustomer
            ? `${selectedCustomer.fullName} - 登录记录`
            : "登录记录"
        }
        open={historyOpen}
        footer={null}
        onCancel={() => { detailRequest.current++; setHistoryOpen(false); }}
        width={920}
      >
        {detailError && <OpsErrorState title={detailError} onRetry={() => selectedCustomer && openLoginHistory(selectedCustomer)} />}
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
                <OpsStatusTag code={value ? "ACTIVE" : "FAILED"} label={value ? "成功" : "失败"} />
              ),
            },
          ]}
          dataSource={loginHistory}
          loading={historyLoading}
        />
      </OpsModal>

      <OpsModal
        title={
          selectedCustomer
            ? `${selectedCustomer.fullName} - 登录风险`
            : "风险详情"
        }
        open={riskOpen}
        footer={null}
        onCancel={() => { detailRequest.current++; setRiskOpen(false); }}
        confirmLoading={riskLoading}
      >
        {riskLoading && <Text type="secondary">正在加载登录风险…</Text>}
        {detailError && <OpsErrorState title={detailError} onRetry={() => selectedCustomer && openLoginRisk(selectedCustomer)} />}
        {selectedRisk && (
          <Descriptions size="small" column={1} bordered>
            <Descriptions.Item label="24小时失败登录">
              {selectedRisk.failedLoginCount24h}
            </Descriptions.Item>
            <Descriptions.Item label="风险等级">
              <OpsStatusTag
                code={riskTag(selectedRisk.riskLevel).color === "red" ? "FAILED" : "ACTIVE"}
                label={riskTag(selectedRisk.riskLevel).text}
              />
            </Descriptions.Item>
            <Descriptions.Item label="最近失败登录">
              {selectedRisk.lastFailedLogin
                ? `${formatDate(selectedRisk.lastFailedLogin.createdAt)} · ${selectedRisk.lastFailedLogin.ipAddress || "—"}`
                : "暂无失败记录"}
            </Descriptions.Item>
          </Descriptions>
        )}
      </OpsModal>

      <OpsModal
        title={sharedType === "IP" ? "共享 IP 风险" : "共享设备风险"}
        open={sharedOpen}
        footer={null}
        width={920}
        onCancel={() => setSharedOpen(false)}
      >
        {!(sharedType === "IP" ? sharedIpReady : sharedDeviceReady) ?
          <OpsErrorState title="风险信息尚未获取，不能判断是否存在共享风险" onRetry={loadCustomers} /> :
        <Table<SharedIpRisk | SharedDeviceRisk>
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
                    render: (_: unknown, record: SharedIpRisk | SharedDeviceRisk) => (
                      <Space orientation="vertical">
                        {record.customers.map((customer) => (
                          <div key={customer.id}>
                            <Tag color="red">{customer.fullName}</Tag>
                            <Text type="secondary">{maskOpsPhone(customer.phone)}</Text>
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
                    render: (_: unknown, record: SharedIpRisk | SharedDeviceRisk) => (
                      <Space orientation="vertical">
                        {record.customers.map((customer) => (
                          <div key={customer.id}>
                            <Tag color="orange">{customer.fullName}</Tag>
                            <Text type="secondary">{maskOpsPhone(customer.phone)}</Text>
                          </div>
                        ))}
                      </Space>
                    ),
                  },
                ]) as ColumnsType<SharedIpRisk | SharedDeviceRisk>
          }
        />}
      </OpsModal>
    </AdminShell>
  );
}
