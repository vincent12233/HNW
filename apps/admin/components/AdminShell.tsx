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
import { Avatar, Button, Layout, Menu, Space, Typography } from "antd";
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
  { key: "/support-console", icon: <SafetyCertificateOutlined />, label: "在线客服" },
  { key: "/deposits", icon: <DollarOutlined />, label: "财务上分" },
  { key: "/withdrawals", icon: <BankOutlined />, label: "提现审核" },
  { key: "/transactions", icon: <TransactionOutlined />, label: "资金流水" },
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
  { key: "/dashboard", icon: <DashboardOutlined />, label: "我的首页" },
  { key: "/business-customers", icon: <TeamOutlined />, label: "我的客户" },
  { key: "/business-kyc", icon: <SafetyCertificateOutlined />, label: "KYC 审核" },
  { key: "/invite-codes", icon: <GiftOutlined />, label: "我的邀请码" },
  { key: "/business-deposits", icon: <DollarOutlined />, label: "客户入金记录" },
  { key: "/business-withdrawals", icon: <BankOutlined />, label: "客户提现记录" },
  { key: "/business-orders", icon: <StockOutlined />, label: "客户订单记录" },
  { key: "/business-trades", icon: <TransactionOutlined />, label: "客户成交记录" },
];

const roleLabels: Record<string, string> = {
  ADMIN: "管理员",
  FINANCE: "财务",
  SUPPORT: "客服",
  BUSINESS: "业务员",
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

  function logout() {
    localStorage.removeItem("adminAccessToken");
    localStorage.removeItem("adminUser");
    router.replace("/login");
  }

  return (
    <Layout style={{ minHeight: "100vh", background: "#f4f6fa" }}>
      <Sider
        collapsible
        collapsed={collapsed}
        trigger={null}
        width={232}
        style={{
          background: "#07192d",
          boxShadow: "4px 0 18px rgba(7,25,45,0.12)",
        }}
      >
        <div
          style={{
            height: 68,
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
              width: 30,
              height: 30,
              borderRadius: 8,
              display: "inline-flex",
              alignItems: "center",
              justifyContent: "center",
              background: "#1f8fff",
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
            background: "#07192d",
            borderInlineEnd: 0,
            paddingInline: 8,
          }}
        />
      </Sider>

      <Layout>
        <Header
          style={{
            paddingInline: 20,
            background: "#fff",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            borderBottom: "1px solid #f0f0f0",
            boxShadow: "0 1px 10px rgba(15,23,42,0.04)",
          }}
        >
          <Button
            type="text"
            icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
            onClick={() => setCollapsed(!collapsed)}
          />

          <Space size="middle">
            <Avatar>{(user?.fullName || "管").charAt(0).toUpperCase()}</Avatar>

            <div style={{ lineHeight: 1.25 }}>
              <Text strong>{user?.fullName || "系统管理员"}</Text>
              <br />
              <Text type="secondary" style={{ fontSize: 12 }}>
                {roleLabels[user?.role || "ADMIN"] || user?.role || "管理员"}
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
            background: "#f4f6fa",
            minHeight: 280,
          }}
        >
          {children}
        </Content>
      </Layout>
    </Layout>
  );
}
