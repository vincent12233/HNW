"use client";

import {
  BankOutlined,
  DollarOutlined,
  GiftOutlined,
  ReloadOutlined,
  RightOutlined,
  SafetyCertificateOutlined,
  StockOutlined,
  TeamOutlined,
  TransactionOutlined,
  UserAddOutlined,
  WalletOutlined,
  WarningOutlined,
} from "@ant-design/icons";
import { Button, Card, Col, Progress, Row, Skeleton, Space, Statistic, Tag, Typography } from "antd";
import { isAxiosError } from "axios";
import Link from "next/link";
import { ReactNode, useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
import CurrentInviteCode from "@/components/CurrentInviteCode";
import OpsErrorState from "@/components/OpsErrorState";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api } from "@/lib/api";
import { formatInr } from "@/lib/ops-format";

const { Paragraph, Text } = Typography;

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
  return formatInr(value);
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
    <Card className="ops-metric-card">
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
  href,
}: {
  title: string;
  description: string;
  icon: ReactNode;
  tone: string;
  href: string;
}) {
  return (
    <Link href={href} className="ops-quick-action">
      <Card hoverable className="ops-quick-card" styles={{ body: { padding: 18 } }}>
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
    </Link>
  );
}

export default function DashboardPage() {
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [businessData, setBusinessData] = useState<BusinessDashboard | null>(null);
  const [businessRisk, setBusinessRisk] = useState<BusinessRiskDashboard | null>(null);
  const [adminRisk, setAdminRisk] = useState<LoginRiskSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [refreshNonce, setRefreshNonce] = useState(0);

  useEffect(() => {
    let active = true;

    async function loadDashboard() {
      setLoading(true);
      setError("");

      try {
        // Use the verified server identity; localStorage may be missing or stale.
        const { data: currentUser } = await api.get<CurrentUser>("/auth/me", { timeout: 12000 });
        if (!active) return;
        setUser(currentUser);
        if (currentUser.role === "BUSINESS" || currentUser.role === "SUPPORT") {
          const [dashboardResponse, riskResponse] = await Promise.all([
            api.get<BusinessDashboard>("/business/my-dashboard", { timeout: 15000 }),
            api.get<BusinessRiskDashboard>("/business/my-risk-dashboard", { timeout: 15000 }),
          ]);

          if (!active) return;
          setBusinessData(dashboardResponse.data);
          setBusinessRisk(riskResponse.data);
        } else {
          const response = await api.get<LoginRiskSummary>("/admin/login-risk-summary", { timeout: 15000 });
          if (!active) return;
          setAdminRisk(response.data);
        }
      } catch (err: unknown) {
        if (!active) return;
        const message = isAxiosError(err) ? err.response?.data?.message : undefined;
        setError(Array.isArray(message) ? message.join("，") : typeof message === "string" ? message : "首页数据加载失败");
      } finally {
        if (active) setLoading(false);
      }
    }

    void loadDashboard();
    return () => { active = false; };
  }, [refreshNonce]);

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

  if (error) {
    return (
      <AdminShell>
        <OpsErrorState
          title="工作台数据暂时不可用"
          description={`${error}。请重试以获取完整数据。`}
          onRetry={() => setRefreshNonce((value) => value + 1)}
        />
      </AdminShell>
    );
  }

  const isBusiness = user?.role === "BUSINESS" || user?.role === "SUPPORT";
  const isSupport = user?.role === "SUPPORT";
  const isFinance = user?.role === "FINANCE";
  const heroTag = isSupport
    ? "专用运营工作台"
    : isBusiness
      ? "业务工作台"
      : isFinance
        ? "资金结算工作台"
        : "运营控制台";
  const heroTitle = isSupport
    ? "固定邀请码客户运营"
    : isBusiness
      ? "我的客户运营"
      : isFinance
        ? "财务实时工作台"
        : "平台实时概览";
  const heroDesc = isFinance
    ? "客户存款完成后由财务单人创建上分订单；提现由客户在 APP 发起，财务审核。无需双人复核。"
    : "聚合客户、资金、风控和待办数据，优先处理会影响入金、提现和账号安全的事项。";

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          eyebrow={heroTag}
          title={heroTitle}
          description={heroDesc}
          extra={
            <Button icon={<ReloadOutlined />} aria-label="刷新工作台" onClick={() => setRefreshNonce((value) => value + 1)}>
              刷新
            </Button>
          }
        />

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
                  href="/business-kyc"
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
                  href="/business-withdrawals"
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

            {isFinance ? (
              <Card title="财务快捷入口" style={{ borderRadius: 8 }}>
                <Row gutter={[12, 12]}>
                  <Col xs={24} md={8}>
                    <QuickAction title="上下分" description="单人操作：按交易账号创建上分或下分" icon={<WalletOutlined />} tone="#0d9488" href="/finance-overview" />
                  </Col>
                  <Col xs={24} md={8}>
                    <QuickAction title="上分订单" description="客户存款完成后核对到账并完成上分" icon={<DollarOutlined />} tone="#c98200" href="/deposits" />
                  </Col>
                  <Col xs={24} md={8}>
                    <QuickAction title="提现审核" description="客户 APP 发起后，核对收款信息并审核" icon={<BankOutlined />} tone="#dc2626" href="/withdrawals" />
                  </Col>
                  <Col xs={24} md={8}>
                    <QuickAction title="资金流水" description="查询账户资金变动记录" icon={<TransactionOutlined />} tone="#7c3aed" href="/transactions" />
                  </Col>
                  <Col xs={24} md={8}>
                    <QuickAction title="贷款处理" description="审核客户贷款申请" icon={<DollarOutlined />} tone="#ea580c" href="/loans" />
                  </Col>
                </Row>
              </Card>
            ) : (
              <Card title="交易产品运营" style={{ borderRadius: 8 }}>
                <Row gutter={[12, 12]}>
                  <Col xs={24} md={8}><QuickAction title="Ins. Stock" description="管理涨停股（机构股票）上架；成交按实时行情结算" icon={<StockOutlined />} tone="#2563eb" href="/watchlist" /></Col>
                  <Col xs={24} md={8}><QuickAction title="OTC" description="管理场外机会、折扣价格和审核订单" icon={<TransactionOutlined />} tone="#0d9488" href="/block-trades" /></Col>
                  <Col xs={24} md={8}><QuickAction title="IPO" description="维护 IPO 状态、认购价和分配记录" icon={<GiftOutlined />} tone="#ef4444" href="/ipo-management" /></Col>
                </Row>
              </Card>
            )}

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
                        {isFinance
                          ? "客户存款完成后，财务单人创建上分订单并执行上下分；提现由客户在 APP 发起，财务审核通过后出金。无需双人复核。"
                          : "客户充值由在线客服确认付款方式，财务确认到账后单人创建上分；提现由客户在 APP 发起后走财务审核。"}
                      </Paragraph>
                    </div>
                  </Space>
                </Card>
              </Col>
              <Col xs={24} lg={10}>
                <Card title="今日工作流" style={{ borderRadius: 8 }}>
                  <Space orientation="vertical" size="middle">
                    <Tag color="blue">客户开户：手机号注册 + 邀请码 + KYC</Tag>
                    <Tag color="green">充值：客服沟通付款，存款完成后财务单人上分</Tag>
                    <Tag color="orange">提现：客户 APP 发起，财务审核后出金</Tag>
                    <Tag color="red">风控：失败登录、共享 IP、共享设备</Tag>
                  </Space>
                </Card>
              </Col>
            </Row>

            {!isFinance && (
              <Row gutter={[16, 16]}>
                <Col xs={24} md={6}>
                  <QuickAction
                    title="客户管理"
                    description="查看客户资料、KYC、账号和登录风险"
                    icon={<TeamOutlined />}
                    tone="#1f8fff"
                    href="/customers"
                  />
                </Col>
                <Col xs={24} md={6}>
                  <QuickAction
                    title="业务员管理"
                    description="管理业务员账号、客户归属和邀请码"
                    icon={<UserAddOutlined />}
                    tone="#16a34a"
                    href="/business-users"
                  />
                </Col>
                <Col xs={24} md={6}>
                  <QuickAction
                    title="操作日志"
                    description="查看账户、资金、IPO、贷款等关键操作"
                    icon={<SafetyCertificateOutlined />}
                    tone="#dc2626"
                    href="/audit-logs"
                  />
                </Col>
                <Col xs={24} md={6}>
                  <QuickAction
                    title="股票管理"
                    description="维护可交易股票、价格和启用状态"
                    icon={<StockOutlined />}
                    tone="#7c3aed"
                    href="/market"
                  />
                </Col>
              </Row>
            )}
          </>
        )}
      </Space>
    </AdminShell>
  );
}

