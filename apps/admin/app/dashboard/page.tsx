"use client";

import {
  BankOutlined,
  DollarOutlined,
  GiftOutlined,
  RightOutlined,
  SafetyCertificateOutlined,
  StockOutlined,
  TeamOutlined,
  UserAddOutlined,
  WalletOutlined,
  WarningOutlined,
} from "@ant-design/icons";
import { Alert, Card, Col, Progress, Row, Skeleton, Space, Statistic, Tag, Typography } from "antd";
import { isAxiosError } from "axios";
import { useRouter } from "next/navigation";
import { ReactNode, useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import CurrentInviteCode from "@/components/CurrentInviteCode";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;

type CurrentUser = {
  id?: string;
  userId?: string;
  role?: string;
  fullName?: string;
};

type BusinessDashboard = {
  totalCustomers: number;
  todayCustomers: number;
  pendingDeposits: number;
  pendingWithdrawals: number;
  pendingKyc: number;
  totalDepositAmount: string;
  totalDepositCount: number;
  totalWithdrawalAmount: string;
  totalWithdrawalCount: number;
  todayDepositAmount: string;
  todayDepositCount: number;
  todayWithdrawalAmount: string;
  todayWithdrawalCount: number;
  pendingIpoApplications: number;
  ipoDebtCustomers: number;
  ipoDebtAmount: number;
  loanOutstandingAmount: string;
  loanOutstandingCount: number;
  totalAssets: number;
  unusedInviteCodes: number;
};

type BusinessRiskDashboard = {
  sharedIpCustomers: number;
  sharedDeviceCustomers: number;
  failedLogin24h: number;
  highRiskCustomers: number;
};

type LoginRiskSummary = {
  failedLoginCount24h: number;
  highRiskCustomers: number;
  mediumRiskCustomers: number;
  totalCustomers: number;
};

function formatMoney(value: number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 2,
  }).format(Number(value ?? 0));
}

function MetricCard({
  title,
  value,
  icon,
  tone,
  suffix,
}: {
  title: string;
  value: string | number;
  icon: ReactNode;
  tone: string;
  suffix?: string;
}) {
  return (
    <Card style={{ borderRadius: 8, border: "1px solid #e8edf5" }}>
      <Space align="start" style={{ justifyContent: "space-between", width: "100%" }}>
        <Statistic title={title} value={value} suffix={suffix} />
        <span
          style={{
            width: 42,
            height: 42,
            borderRadius: 8,
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            background: tone,
            color: "#fff",
            fontSize: 18,
          }}
        >
          {icon}
        </span>
      </Space>
    </Card>
  );
}

function QuickAction({
  title,
  description,
  icon,
  tone,
  onClick,
}: {
  title: string;
  description: string;
  icon: ReactNode;
  tone: string;
  onClick: () => void;
}) {
  return (
    <Card
      hoverable
      onClick={onClick}
      style={{ borderRadius: 8, border: "1px solid #e8edf5" }}
      styles={{ body: { padding: 18 } }}
    >
      <Space align="start" style={{ width: "100%", justifyContent: "space-between" }}>
        <Space align="start">
          <span
            style={{
              width: 38,
              height: 38,
              borderRadius: 8,
              display: "inline-flex",
              alignItems: "center",
              justifyContent: "center",
              background: tone,
              color: "#fff",
              fontSize: 17,
            }}
          >
            {icon}
          </span>
          <div>
            <Text strong>{title}</Text>
            <Paragraph type="secondary" style={{ marginBottom: 0, marginTop: 3 }}>
              {description}
            </Paragraph>
          </div>
        </Space>
        <RightOutlined style={{ color: "#94a3b8", marginTop: 10 }} />
      </Space>
    </Card>
  );
}

export default function DashboardPage() {
  const router = useRouter();
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [businessData, setBusinessData] = useState<BusinessDashboard | null>(null);
  const [businessRisk, setBusinessRisk] = useState<BusinessRiskDashboard | null>(null);
  const [adminRisk, setAdminRisk] = useState<LoginRiskSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    async function loadStoredUser() {
      const storedUser = localStorage.getItem("adminUser");
      if (!storedUser) return;
      try {
        setUser(JSON.parse(storedUser));
      } catch {
        setUser(null);
      }
    }
    void loadStoredUser();
  }, []);

  useEffect(() => {
    if (!user) return;
    const currentUser = user;

    async function loadDashboard() {
      setLoading(true);
      setError("");

      try {
        if (currentUser.role === "BUSINESS" || currentUser.role === "SUPPORT") {
          const [dashboardResponse, riskResponse] = await Promise.all([
            api.get<BusinessDashboard>("/business/my-dashboard"),
            api.get<BusinessRiskDashboard>("/business/my-risk-dashboard"),
          ]);

          setBusinessData(dashboardResponse.data);
          setBusinessRisk(riskResponse.data);
        } else {
          const response = await api.get<LoginRiskSummary>("/admin/login-risk-summary");
          setAdminRisk(response.data);
        }
      } catch (err: unknown) {
        const message = isAxiosError(err) ? err.response?.data?.message : undefined;
        setError(Array.isArray(message) ? message.join("，") : typeof message === "string" ? message : "首页数据加载失败");
      } finally {
        setLoading(false);
      }
    }

    loadDashboard();
  }, [user]);

  const adminRiskPercent = useMemo(() => {
    const total = adminRisk?.totalCustomers ?? 0;
    if (!total) return 0;
    return Math.round(((adminRisk?.highRiskCustomers ?? 0) / total) * 100);
  }, [adminRisk]);

  if (loading) {
    return (
      <AdminShell>
        <Skeleton active />
      </AdminShell>
    );
  }

  const isBusiness = user?.role === "BUSINESS" || user?.role === "SUPPORT";
  const isSupport = user?.role === "SUPPORT";

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <div
          style={{
            borderRadius: 8,
            padding: 24,
            background: "linear-gradient(135deg, #07192d 0%, #123e66 62%, #1f8fff 100%)",
            color: "#fff",
          }}
        >
          <Space orientation="vertical" size={4}>
            <Tag color="blue">{isSupport ? "专用运营工作台" : isBusiness ? "业务工作台" : "运营控制台"}</Tag>
            <Title level={2} style={{ color: "#fff", margin: 0 }}>
              {isSupport ? "固定邀请码客户运营" : isBusiness ? "我的客户运营" : "平台实时概览"}
            </Title>
            <Paragraph style={{ color: "rgba(255,255,255,0.72)", margin: 0 }}>
              聚合客户、资金、风控和待办数据，优先处理会影响入金、提现和账号安全的事项。
            </Paragraph>
          </Space>
        </div>

        {error && <Alert type="error" showIcon title={error} />}

        {isBusiness ? (
          <>
            <Row gutter={[16, 16]}>
              <Col xs={24} md={8}>
                <MetricCard title="我的客户" value={businessData?.totalCustomers ?? 0} icon={<TeamOutlined />} tone="#1f8fff" />
              </Col>
              <Col xs={24} md={8}>
                <MetricCard title="今日新增" value={businessData?.todayCustomers ?? 0} icon={<UserAddOutlined />} tone="#16a34a" />
              </Col>
              <Col xs={24} md={8}>
                <MetricCard title="客户资产" value={formatMoney(businessData?.totalAssets ?? 0)} icon={<WalletOutlined />} tone="#7c3aed" />
              </Col>
              <Col xs={24} md={8}>
                <MetricCard title="待 KYC" value={businessData?.pendingKyc ?? 0} icon={<SafetyCertificateOutlined />} tone="#0ea5e9" />
              </Col>
              <Col xs={24} md={8}>
                <MetricCard title="待处理提现" value={businessData?.pendingWithdrawals ?? 0} icon={<BankOutlined />} tone="#dc2626" />
              </Col>
              <Col xs={24} md={8}>
                <MetricCard title="IPO 待分配" value={businessData?.pendingIpoApplications ?? 0} icon={<StockOutlined />} tone="#2563eb" />
              </Col>
              <Col xs={24} md={8}>
                <MetricCard title="IPO 欠款" value={formatMoney(Number(businessData?.ipoDebtAmount ?? 0))} icon={<WarningOutlined />} tone="#ef4444" />
              </Col>
              {!isSupport && <Col xs={24} md={8}>
                <MetricCard title="贷款未还" value={formatMoney(Number(businessData?.loanOutstandingAmount ?? 0))} icon={<DollarOutlined />} tone="#ea580c" />
              </Col>}
              {!isSupport && <Col xs={24} md={8}>
                <MetricCard title="未使用邀请码" value={businessData?.unusedInviteCodes ?? 0} icon={<GiftOutlined />} tone="#f59e0b" />
              </Col>}
              <Col xs={24} md={8}>
                <MetricCard title="高风险客户" value={businessRisk?.highRiskCustomers ?? 0} icon={<WarningOutlined />} tone="#ef4444" />
              </Col>
            </Row>

            <Card title="资金观察" style={{ borderRadius: 8 }}>
              <Row gutter={[16, 16]}>
                <Col xs={24} md={6}>
                  <Statistic title="当日总提现" value={formatMoney(Number(businessData?.todayWithdrawalAmount ?? 0))} />
                </Col>
                <Col xs={24} md={6}>
                  <Statistic title="当日总充值" value={formatMoney(Number(businessData?.todayDepositAmount ?? 0))} />
                </Col>
                <Col xs={24} md={6}>
                  <Statistic title="客户累计入金" value={formatMoney(Number(businessData?.totalDepositAmount ?? 0))} />
                </Col>
                <Col xs={24} md={6}>
                  <Statistic title="客户累计提现" value={formatMoney(Number(businessData?.totalWithdrawalAmount ?? 0))} />
                </Col>
              </Row>
            </Card>

            <Row gutter={[16, 16]}>
              <Col xs={24} md={8}>
                <QuickAction
                  title="审核 KYC"
                  description="处理自己客户提交的 Aadhaar / PAN 文件"
                  icon={<SafetyCertificateOutlined />}
                  tone="#1f8fff"
                  onClick={() => router.push("/business-kyc")}
                />
              </Col>
              {!isSupport && <Col xs={24} md={8}>
                <CurrentInviteCode />
              </Col>}
              <Col xs={24} md={8}>
                <QuickAction
                  title="客户提现记录"
                  description="查看自己客户提交的提现订单号和状态"
                  icon={<BankOutlined />}
                  tone="#dc2626"
                  onClick={() => router.push("/business-withdrawals")}
                />
              </Col>
            </Row>
          </>
        ) : (
          <>
            <Row gutter={[16, 16]}>
              <Col xs={24} md={6}>
                <MetricCard title="客户总数" value={adminRisk?.totalCustomers ?? 0} icon={<TeamOutlined />} tone="#1f8fff" />
              </Col>
              <Col xs={24} md={6}>
                <MetricCard title="失败登录" value={adminRisk?.failedLoginCount24h ?? 0} icon={<SafetyCertificateOutlined />} tone="#f59e0b" />
              </Col>
              <Col xs={24} md={6}>
                <MetricCard title="中风险客户" value={adminRisk?.mediumRiskCustomers ?? 0} icon={<WarningOutlined />} tone="#fb7185" />
              </Col>
              <Col xs={24} md={6}>
                <MetricCard title="高风险客户" value={adminRisk?.highRiskCustomers ?? 0} icon={<WarningOutlined />} tone="#dc2626" />
              </Col>
            </Row>

            <Card title="交易产品运营" style={{ borderRadius: 8 }}>
              <Row gutter={[12, 12]}>
                <Col xs={24} md={8}><QuickAction title="Ins. Stock" description="管理机构股票上架、报价和预期收益" icon={<StockOutlined />} tone="#2563eb" onClick={() => router.push("/watchlist")} /></Col>
                <Col xs={24} md={8}><QuickAction title="OTC" description="管理场外机会、折扣价格和审核订单" icon={<TransactionOutlined />} tone="#0d9488" onClick={() => router.push("/block-trades")} /></Col>
                <Col xs={24} md={8}><QuickAction title="IPO" description="维护 IPO 状态、认购价和分配记录" icon={<GiftOutlined />} tone="#ef4444" onClick={() => router.push("/ipo-management")} /></Col>
              </Row>
            </Card>

            <Row gutter={[16, 16]}>
              <Col xs={24} lg={14}>
                <Card title="运营优先级" style={{ borderRadius: 8 }}>
                  <Space orientation="vertical" size="middle" style={{ width: "100%" }}>
                    <div>
                      <Text strong>高风险客户占比</Text>
                      <Progress percent={adminRiskPercent} strokeColor="#dc2626" />
                    </div>
                    <div>
                      <Text strong>财务处理建议</Text>
                      <Paragraph type="secondary" style={{ marginBottom: 0 }}>
                        客户充值由在线客服确认付款方式，财务在“财务上分”中按交易账号手动入账；提现仍走后台审核。
                      </Paragraph>
                    </div>
                  </Space>
                </Card>
              </Col>
              <Col xs={24} lg={10}>
                <Card title="今日工作流" style={{ borderRadius: 8 }}>
                  <Space orientation="vertical" size="middle">
                    <Tag color="blue">客户开户：手机号注册 + 邀请码 + KYC</Tag>
                    <Tag color="green">充值：在线客服沟通，财务手动上分</Tag>
                    <Tag color="orange">提现：后台审核后扣款出金</Tag>
                    <Tag color="red">风控：失败登录、共享 IP、共享设备</Tag>
                  </Space>
                </Card>
              </Col>
            </Row>

            <Row gutter={[16, 16]}>
              <Col xs={24} md={6}>
                <QuickAction
                  title="客户管理"
                  description="查看客户资料、KYC、账号和登录风险"
                  icon={<TeamOutlined />}
                  tone="#1f8fff"
                  onClick={() => router.push("/customers")}
                />
              </Col>
              <Col xs={24} md={6}>
                <QuickAction
                  title="业务员管理"
                  description="管理业务员账号、客户归属和邀请码"
                  icon={<UserAddOutlined />}
                  tone="#16a34a"
                  onClick={() => router.push("/business-users")}
                />
              </Col>
              <Col xs={24} md={6}>
                <QuickAction
                  title="操作日志"
                  description="查看账户、资金、IPO、贷款等关键操作"
                  icon={<SafetyCertificateOutlined />}
                  tone="#dc2626"
                  onClick={() => router.push("/audit-logs")}
                />
              </Col>
              <Col xs={24} md={6}>
                <QuickAction
                  title="股票管理"
                  description="维护可交易股票、价格和启用状态"
                  icon={<StockOutlined />}
                  tone="#7c3aed"
                  onClick={() => router.push("/market")}
                />
              </Col>
            </Row>
          </>
        )}
      </Space>
    </AdminShell>
  );
}

