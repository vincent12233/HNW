"use client";

import {
  BankOutlined,
  BarChartOutlined,
  DashboardOutlined,
  DollarOutlined,
  GiftOutlined,
  LogoutOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  SafetyCertificateOutlined,
  StockOutlined,
  TeamOutlined,
  TransactionOutlined,
  UsergroupAddOutlined,
  WarningOutlined,
} from "@ant-design/icons";
import { Avatar, Button, Layout, Menu, Space, Tag, Typography } from "antd";
import { usePathname, useRouter } from "next/navigation";
import { ReactNode, useEffect, useMemo, useState } from "react";

const { Header, Sider, Content } = Layout;
const { Text } = Typography;

type AdminShellProps = {
  children: ReactNode;
};

type CurrentUser = {
  id?: string;
  fullName?: string;
  phone?: string;
  role?: string;
};

const adminMenuItems = [
  { key: "/dashboard", icon: <DashboardOutlined />, label: "控制台" },
  { key: "/customers", icon: <TeamOutlined />, label: "客户管理" },
  { key: "/business-users", icon: <UsergroupAddOutlined />, label: "业务员管理" },
  { key: "/audit-logs", icon: <SafetyCertificateOutlined />, label: "操作日志" },
  { key: "/orders", icon: <StockOutlined />, label: "订单查询" },
  { key: "/trades", icon: <TransactionOutlined />, label: "成交查询" },
  { key: "/market", icon: <StockOutlined />, label: "股票管理" },
  { key: "/watchlist", icon: <StockOutlined />, label: "自选股" },
  { key: "/block-trades", icon: <BankOutlined />, label: "大宗交易" },
  { key: "/ipo-debts", icon: <WarningOutlined />, label: "IPO 欠款" },
  { key: "/funds", icon: <GiftOutlined />, label: "基金" },
  { key: "/quant", icon: <BarChartOutlined />, label: "量化" },
];

const financeMenuItems = [
  { key: "/dashboard", icon: <DashboardOutlined />, label: "财务首页" },
  { key: "/deposits", icon: <DollarOutlined />, label: "财务上分" },
  { key: "/withdrawals", icon: <BankOutlined />, label: "提现审核" },
  { key: "/loans", icon: <DollarOutlined />, label: "贷款管理" },
  { key: "/finance-overview", icon: <TransactionOutlined />, label: "资金总览" },
  { key: "/transactions", icon: <TransactionOutlined />, label: "资金流水" },
  { key: "/orders", icon: <StockOutlined />, label: "订单查询" },
  { key: "/trades", icon: <TransactionOutlined />, label: "成交查询" },
  { key: "/customers", icon: <TeamOutlined />, label: "客户查询" },
];

const supportMenuItems = [
  { key: "/dashboard", icon: <DashboardOutlined />, label: "客服首页" },
  { key: "/support-console", icon: <SafetyCertificateOutlined />, label: "在线客服" },
  { key: "/customers", icon: <TeamOutlined />, label: "客户查询" },
];

const businessMenuItems = [
  { key: "/dashboard", icon: <DashboardOutlined />, label: "控制台" },
  { key: "/business-customers", icon: <TeamOutlined />, label: "客户管理" },
  { key: "/business-accounts", icon: <BankOutlined />, label: "账户管理" },
  { key: "/business-funds", icon: <DollarOutlined />, label: "资金管理" },
  { key: "/business-kyc", icon: <SafetyCertificateOutlined />, label: "KYC 审核" },
  { key: "/business-ipo", icon: <WarningOutlined />, label: "IPO 分配" },
  { key: "/invite-codes", icon: <GiftOutlined />, label: "我的邀请码" },
  { key: "/business-orders", icon: <StockOutlined />, label: "客户订单记录" },
  { key: "/business-trades", icon: <TransactionOutlined />, label: "客户成交记录" },
  { key: "/business-institutional", icon: <StockOutlined />, label: "涨停股" },
  { key: "/business-otc", icon: <BankOutlined />, label: "OTC" },
];

const roleLabels: Record<string, string> = {
  ADMIN: "管理员",
  FINANCE: "财务",
  SUPPORT: "客服",
  BUSINESS: "业务员",
};

const pageTitles: Record<string, string> = {
  "/dashboard": "控制台",
  "/customers": "客户管理",
  "/business-users": "业务员管理",
  "/support-console": "在线客服",
  "/deposits": "财务上分",
  "/withdrawals": "提现审核",
  "/loans": "贷款管理",
  "/finance-overview": "资金总览",
  "/transactions": "资金流水",
  "/audit-logs": "操作日志",
  "/orders": "订单查询",
  "/trades": "成交查询",
  "/market": "股票管理",
  "/watchlist": "自选股",
  "/block-trades": "大宗交易",
  "/ipo-debts": "IPO 欠款",
  "/funds": "基金",
  "/quant": "量化",
  "/business-customers": "客户管理",
  "/business-accounts": "账户管理",
  "/business-funds": "资金管理",
  "/business-kyc": "KYC 审核",
  "/business-ipo": "IPO 分配",
  "/invite-codes": "我的邀请码",
  "/business-deposits": "客户入金记录",
  "/business-withdrawals": "客户提现记录",
  "/business-orders": "客户订单记录",
  "/business-trades": "客户成交记录",
  "/business-institutional": "涨停股",
  "/business-otc": "OTC",
};

export default function AdminShell({ children }: AdminShellProps) {
  const router = useRouter();
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const [user, setUser] = useState<CurrentUser | null>(null);

  useEffect(() => {
    const token = localStorage.getItem("adminAccessToken");
    const storedUser = localStorage.getItem("adminUser");

    if (!token) {
      router.replace("/login");
      return;
    }

    if (storedUser) {
      try {
        setUser(JSON.parse(storedUser));
      } catch {
        localStorage.removeItem("adminUser");
        router.replace("/login");
      }
    }
  }, [router]);

  const menuItems = useMemo(() => {
    if (user?.role === "BUSINESS") return businessMenuItems;
    if (user?.role === "FINANCE") return financeMenuItems;
    if (user?.role === "SUPPORT") return supportMenuItems;
    return adminMenuItems;
  }, [user?.role]);

  const productName = useMemo(() => {
    if (user?.role === "BUSINESS") return "HNW 业务后台";
    if (user?.role === "FINANCE") return "HNW 财务后台";
    if (user?.role === "SUPPORT") return "HNW 客服后台";
    return "HNW 管理后台";
  }, [user?.role]);

  const pageTitle = pageTitles[pathname] || "工作台";

  function logout() {
    localStorage.removeItem("adminAccessToken");
    localStorage.removeItem("adminUser");
    router.replace("/login");
  }

  return (
    <Layout style={{ minHeight: "100vh", background: "#eef3f8" }}>
      <Sider
        collapsible
        collapsed={collapsed}
        trigger={null}
        width={232}
        style={{
          background: "linear-gradient(180deg, #07192d 0%, #0b2038 56%, #0d2a4a 100%)",
          boxShadow: "6px 0 24px rgba(7,25,45,0.16)",
        }}
      >
        <div
          style={{
            height: 76,
            display: "flex",
            alignItems: "center",
            gap: 10,
            paddingInline: collapsed ? 16 : 20,
            color: "#fff",
            fontWeight: 700,
            fontSize: collapsed ? 16 : 18,
          }}
        >
          <span
            style={{
              width: 34,
              height: 34,
              borderRadius: 10,
              display: "inline-flex",
              alignItems: "center",
              justifyContent: "center",
              background: "linear-gradient(135deg, #1f8fff, #60a5fa)",
              fontSize: 13,
            }}
          >
            H
          </span>
          {!collapsed && <span>{productName}</span>}
        </div>

        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[pathname]}
          items={menuItems}
          onClick={({ key }) => router.push(key)}
          style={{
            background: "transparent",
            borderInlineEnd: 0,
            paddingInline: 8,
          }}
        />
      </Sider>

      <Layout>
        <Header
          style={{
            paddingInline: 20,
            background: "rgba(255,255,255,0.92)",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            borderBottom: "1px solid #e8edf5",
            boxShadow: "0 8px 24px rgba(15,23,42,0.06)",
            position: "sticky",
            top: 0,
            zIndex: 10,
          }}
        >
          <Space size="middle">
            <Button
              type="text"
              icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
              onClick={() => setCollapsed(!collapsed)}
            />
            <div style={{ lineHeight: 1.2 }}>
              <Text type="secondary" style={{ fontSize: 12 }}>
                HNW Operations
              </Text>
              <br />
              <Text strong style={{ fontSize: 18 }}>
                {pageTitle}
              </Text>
            </div>
          </Space>

          <Space size="middle">
            <Tag color={user?.role === "BUSINESS" ? "green" : user?.role === "FINANCE" ? "gold" : user?.role === "SUPPORT" ? "blue" : "purple"}>
              {roleLabels[user?.role || "ADMIN"] || user?.role || "管理员"}
            </Tag>

            <Avatar style={{ background: "#1f8fff" }}>
              {(user?.fullName || "管").charAt(0).toUpperCase()}
            </Avatar>

            <div style={{ lineHeight: 1.25 }}>
              <Text strong>{user?.fullName || "系统管理员"}</Text>
              <br />
              <Text type="secondary" style={{ fontSize: 12 }}>
                员工编号登录
              </Text>
            </div>

            <Button icon={<LogoutOutlined />} onClick={logout}>
              退出登录
            </Button>
          </Space>
        </Header>

        <Content
          style={{
            margin: 0,
            padding: 24,
            background: "#eef3f8",
            minHeight: 280,
          }}
        >
          {children}
        </Content>
      </Layout>
    </Layout>
  );
}
