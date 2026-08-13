"use client";

import {
  AuditOutlined, BankOutlined, BarChartOutlined, CustomerServiceOutlined,
  DashboardOutlined, DollarOutlined, GiftOutlined, IdcardOutlined,
  LogoutOutlined, MenuFoldOutlined, MenuUnfoldOutlined, SafetyCertificateOutlined,
  StockOutlined, TeamOutlined, TransactionOutlined, UsergroupAddOutlined,
} from "@ant-design/icons";
import { Avatar, Button, Drawer, Layout, Menu, Space, Tag, Typography } from "antd";
import { usePathname, useRouter } from "next/navigation";
import { ReactNode, useEffect, useMemo, useState } from "react";

const { Header, Sider, Content } = Layout;
const { Text } = Typography;
type Role = "ADMIN" | "BUSINESS" | "FINANCE" | "SUPPORT";
type CurrentUser = { id?: string; fullName?: string; phone?: string; role?: Role };
type MenuItem = { key: string; icon: ReactNode; label: string };

const menus: Record<Role, MenuItem[]> = {
  ADMIN: [
    { key: "/dashboard", icon: <DashboardOutlined />, label: "管理总览" },
    { key: "/business-users", icon: <UsergroupAddOutlined />, label: "员工与权限" },
    { key: "/customers", icon: <TeamOutlined />, label: "客户总览" },
    { key: "/market", icon: <StockOutlined />, label: "市场运行" },
    { key: "/instruments", icon: <StockOutlined />, label: "股票资料库" },
    { key: "/watchlist", icon: <BarChartOutlined />, label: "Inst. 上架" },
    { key: "/block-trades", icon: <BankOutlined />, label: "OTC 上架" },
    { key: "/ipo-management", icon: <GiftOutlined />, label: "IPO 上架" },
    { key: "/audit-logs", icon: <AuditOutlined />, label: "安全审计" },
  ],
  BUSINESS: [
    { key: "/dashboard", icon: <DashboardOutlined />, label: "业务总览" },
    { key: "/business-customers", icon: <TeamOutlined />, label: "我的客户" },
    { key: "/business-kyc", icon: <IdcardOutlined />, label: "KYC 审核" },
    { key: "/business-accounts", icon: <BankOutlined />, label: "客户账户" },
    { key: "/invite-codes", icon: <GiftOutlined />, label: "邀请码" },
    { key: "/business-institutional", icon: <StockOutlined />, label: "Inst. 业务" },
    { key: "/business-otc", icon: <TransactionOutlined />, label: "OTC 审核" },
    { key: "/business-ipo", icon: <GiftOutlined />, label: "IPO 分配" },
    { key: "/business-positions", icon: <BarChartOutlined />, label: "客户持仓" },
    { key: "/business-orders", icon: <StockOutlined />, label: "客户订单" },
    { key: "/business-trades", icon: <TransactionOutlined />, label: "客户成交" },
  ],
  FINANCE: [
    { key: "/dashboard", icon: <DashboardOutlined />, label: "财务工作台" },
    { key: "/deposits", icon: <DollarOutlined />, label: "入金审核" },
    { key: "/withdrawals", icon: <BankOutlined />, label: "提现审核" },
    { key: "/finance-overview", icon: <BarChartOutlined />, label: "资金对账" },
    { key: "/transactions", icon: <TransactionOutlined />, label: "资金流水" },
    { key: "/bank-accounts", icon: <BankOutlined />, label: "银行账户" },
    { key: "/loans", icon: <DollarOutlined />, label: "贷款处理" },
  ],
  SUPPORT: [
    { key: "/dashboard", icon: <DashboardOutlined />, label: "客服工作台" },
    { key: "/support-console", icon: <CustomerServiceOutlined />, label: "在线会话" },
    { key: "/customers", icon: <TeamOutlined />, label: "客户资料查询" },
  ],
};

const roleMeta: Record<Role, { label: string; product: string; color: string }> = {
  ADMIN: { label: "超级管理员", product: "平台治理后台", color: "purple" },
  BUSINESS: { label: "业务员", product: "客户业务后台", color: "green" },
  FINANCE: { label: "财务", product: "资金结算后台", color: "gold" },
  SUPPORT: { label: "客服", product: "客户服务后台", color: "blue" },
};

export default function AdminShell({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const [mobile, setMobile] = useState(false);
  const [drawer, setDrawer] = useState(false);
  const [user, setUser] = useState<CurrentUser | null>(null);

  useEffect(() => {
    const sync = () => setMobile(window.innerWidth < 900);
    sync(); window.addEventListener("resize", sync);
    return () => window.removeEventListener("resize", sync);
  }, []);
  useEffect(() => {
    const token = localStorage.getItem("adminAccessToken");
    const stored = localStorage.getItem("adminUser");
    if (!token || !stored) { router.replace("/login"); return; }
    try {
      const parsed = JSON.parse(stored) as CurrentUser;
      if (!parsed.role || !menus[parsed.role]) throw new Error("Invalid role");
      setUser(parsed);
    } catch {
      localStorage.removeItem("adminAccessToken");
      localStorage.removeItem("adminUser");
      router.replace("/login");
    }
  }, [router]);

  const role: Role = user?.role || "ADMIN";
  const items = useMemo(() => menus[role], [role]);
  const meta = roleMeta[role];
  const pageTitle = items.find((item) => pathname.startsWith(item.key))?.label || "工作台";
  const allowed = pathname === "/" || pathname === "/login" || items.some((item) => pathname.startsWith(item.key));
  useEffect(() => { if (user && !allowed) router.replace("/dashboard"); }, [allowed, router, user]);
  const logout = () => {
    localStorage.removeItem("adminAccessToken");
    localStorage.removeItem("adminUser");
    router.replace("/login");
  };
  const menu = <Menu theme="dark" mode="inline" selectedKeys={[pathname]} items={items} onClick={({ key }) => { router.push(key); setDrawer(false); }} className="ops-menu" />;
  const brand = <div className="ops-brand"><span className="ops-logo"><StockOutlined /></span>{!collapsed && <div><strong>India Trading</strong><small>{meta.product}</small></div>}</div>;

  return <Layout className="ops-layout">
    {!mobile && <Sider width={256} collapsedWidth={76} collapsed={collapsed} trigger={null} className="ops-sider">{brand}{menu}</Sider>}
    <Drawer placement="left" width={280} open={mobile && drawer} onClose={() => setDrawer(false)} styles={{ body: { padding: 0, background: "#071426" }, header: { display: "none" } }}><div className="ops-mobile-nav">{brand}{menu}</div></Drawer>
    <Layout>
      <Header className="ops-header">
        <Space><Button type="text" aria-label="切换导航" icon={mobile || collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />} onClick={() => mobile ? setDrawer(true) : setCollapsed(!collapsed)} /><div className="ops-title"><Text type="secondary">OPERATIONS WORKSPACE</Text><strong>{pageTitle}</strong></div></Space>
        <Space size={mobile ? 8 : 14}><Tag color={meta.color}>{meta.label}</Tag>{!mobile && <><Avatar className="ops-avatar">{(user?.fullName || "管").charAt(0)}</Avatar><div className="ops-user"><strong>{user?.fullName || meta.label}</strong><small>安全登录</small></div></>}<Button type="text" danger icon={<LogoutOutlined />} onClick={logout}>{mobile ? null : "退出"}</Button></Space>
      </Header>
      <Content className="ops-content">{allowed ? children : null}</Content>
    </Layout>
  </Layout>;
}
