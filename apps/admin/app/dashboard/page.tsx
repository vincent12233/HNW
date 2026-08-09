"use client";

import {
  BankOutlined,
  DollarOutlined,
  GiftOutlined,
  SafetyCertificateOutlined,
  TeamOutlined,
  UserAddOutlined,
  WalletOutlined,
  WarningOutlined,
} from "@ant-design/icons";
import { Alert, Card, Col, Progress, Row, Skeleton, Space, Statistic, Tag, Typography } from "antd";
import { ReactNode, useEffect, useMemo, useState } from "react";

import AdminShell from "@/components/AdminShell";
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

export default function DashboardPage() {
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [businessData, setBusinessData] = useState<BusinessDashboard | null>(null);
  const [businessRisk, setBusinessRisk] = useState<BusinessRiskDashboard | null>(null);
  const [adminRisk, setAdminRisk] = useState<LoginRiskSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const storedUser = localStorage.getItem("adminUser");

    if (storedUser) {
      try {
        setUser(JSON.parse(storedUser));
      } catch {
        setUser(null);
      }
    }
  }, []);

  useEffect(() => {
    if (!user) return;
    const currentUser = user;

    async function loadDashboard() {
      setLoading(true);
      setError("");

      try {
        if (currentUser.role === "BUSINESS") {
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
      } catch (err: any) {
        const message = err.response?.data?.message;
        setError(Array.isArray(message) ? message.join("，") : message || "首页数据加载失败");
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

  const isBusiness = user?.role === "BUSINESS";

  return (
    <AdminShell>
      <Space direction="vertical" size="large" style={{ width: "100%" }}>
        <div
          style={{
            borderRadius: 8,
            padding: 24,
            background: "linear-gradient(135deg, #07192d 0%, #123e66 62%, #1f8fff 100%)",
            color: "#fff",
          }}
        >
          <Space direction="vertical" size={4}>
            <Tag color="blue">{isBusiness ? "业务工作台" : "运营控制台"}</Tag>
            <Title level={2} style={{ color: "#fff", margin: 0 }}>
              {isBusiness ? "我的客户运营" : "平台实时概览"}
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
                <MetricCard title="待处理提现" value={businessData?.pendingWithdrawals ?? 0} icon={<BankOutlined />} tone="#dc2626" />
              </Col>
              <Col xs={24} md={8}>
                <MetricCard title="未使用邀请码" value={businessData?.unusedInviteCodes ?? 0} icon={<GiftOutlined />} tone="#f59e0b" />
              </Col>
              <Col xs={24} md={8}>
                <MetricCard title="高风险客户" value={businessRisk?.highRiskCustomers ?? 0} icon={<WarningOutlined />} tone="#ef4444" />
              </Col>
            </Row>

            <Card title="风控观察" style={{ borderRadius: 8 }}>
              <Row gutter={[16, 16]}>
                <Col xs={24} md={8}>
                  <Statistic title="24小时失败登录" value={businessRisk?.failedLogin24h ?? 0} />
                </Col>
                <Col xs={24} md={8}>
                  <Statistic title="共享 IP 客户" value={businessRisk?.sharedIpCustomers ?? 0} />
                </Col>
                <Col xs={24} md={8}>
                  <Statistic title="共享设备客户" value={businessRisk?.sharedDeviceCustomers ?? 0} />
                </Col>
              </Row>
            </Card>
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

            <Row gutter={[16, 16]}>
              <Col xs={24} lg={14}>
                <Card title="运营优先级" style={{ borderRadius: 8 }}>
                  <Space direction="vertical" size="middle" style={{ width: "100%" }}>
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
                  <Space direction="vertical" size="middle">
                    <Tag color="blue">客户开户：手机号注册 + 邀请码 + KYC</Tag>
                    <Tag color="green">充值：在线客服沟通，财务手动上分</Tag>
                    <Tag color="orange">提现：后台审核后扣款出金</Tag>
                    <Tag color="red">风控：失败登录、共享 IP、共享设备</Tag>
                  </Space>
                </Card>
              </Col>
            </Row>
          </>
        )}
      </Space>
    </AdminShell>
  );
}
