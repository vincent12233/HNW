"use client";

import {
  BankOutlined, BarChartOutlined, DashboardOutlined, DollarOutlined,
  GiftOutlined, LogoutOutlined, MenuFoldOutlined, MenuUnfoldOutlined,
  SafetyCertificateOutlined, StockOutlined, TeamOutlined,
  TransactionOutlined, UsergroupAddOutlined, WarningOutlined,
} from "@ant-design/icons";
import { Avatar, Button, Drawer, Layout, Menu, Space, Tag, Typography } from "antd";
import { usePathname, useRouter } from "next/navigation";
import { ReactNode, useEffect, useMemo, useState } from "react";

const { Header, Sider, Content } = Layout;
const { Text } = Typography;
type CurrentUser = { id?: string; fullName?: string; phone?: string; role?: string };
type MenuItem = { key: string; icon?: ReactNode; label: string };

const adminItems: MenuItem[] = [
  { key: "/dashboard", icon: <DashboardOutlined />, label: "运营总览" },
  { key: "/customers", icon: <TeamOutlined />, label: "客户管理" },
  { key: "/business-users", icon: <UsergroupAddOutlined />, label: "业务员管理" },
  { key: "/bank-accounts", icon: <BankOutlined />, label: "银行账户" },
  { key: "/orders", icon: <StockOutlined />, label: "订单查询" },
  { key: "/trades", icon: <TransactionOutlined />, label: "成交查询" },
  { key: "/market", icon: <StockOutlined />, label: "股票管理" },
  { key: "/instruments", icon: <StockOutlined />, label: "NSE 股票库" },
  { key: "/watchlist", icon: <StockOutlined />, label: "Inst. 上架管理" },
  { key: "/block-trades", icon: <BankOutlined />, label: "OTC 上架管理" },
  { key: "/ipo-management", icon: <GiftOutlined />, label: "IPO 上架管理" },
  { key: "/ipo-debts", icon: <WarningOutlined />, label: "IPO 欠款" },
  { key: "/funds", icon: <GiftOutlined />, label: "产品管理" },
  { key: "/quant", icon: <BarChartOutlined />, label: "量化管理" },
  { key: "/audit-logs", icon: <SafetyCertificateOutlined />, label: "操作日志" },
];
const financeItems: MenuItem[] = [
  { key: "/dashboard", icon: <DashboardOutlined />, label: "财务总览" },
  { key: "/deposits", icon: <DollarOutlined />, label: "入金处理" },
  { key: "/withdrawals", icon: <BankOutlined />, label: "提现审核" },
  { key: "/loans", icon: <DollarOutlined />, label: "贷款管理" },
  { key: "/finance-overview", icon: <TransactionOutlined />, label: "资金总览" },
  { key: "/transactions", icon: <TransactionOutlined />, label: "资金流水" },
  { key: "/bank-accounts", icon: <BankOutlined />, label: "银行账户" },
  { key: "/orders", icon: <StockOutlined />, label: "订单查询" },
  { key: "/trades", icon: <TransactionOutlined />, label: "成交查询" },
  { key: "/customers", icon: <TeamOutlined />, label: "客户查询" },
];
const supportItems: MenuItem[] = [
  { key: "/dashboard", icon: <DashboardOutlined />, label: "客服总览" },
  { key: "/support-console", icon: <SafetyCertificateOutlined />, label: "在线客服" },
  { key: "/customers", icon: <TeamOutlined />, label: "客户查询" },
];
const businessItems: MenuItem[] = [
  { key: "/dashboard", icon: <DashboardOutlined />, label: "业务总览" },
  { key: "/business-customers", icon: <TeamOutlined />, label: "客户管理" },
  { key: "/business-accounts", icon: <BankOutlined />, label: "账户管理" },
  { key: "/business-funds", icon: <DollarOutlined />, label: "资金管理" },
  { key: "/business-kyc", icon: <SafetyCertificateOutlined />, label: "KYC 审核" },
  { key: "/business-ipo", icon: <WarningOutlined />, label: "IPO 分配" },
  { key: "/business-positions", icon: <StockOutlined />, label: "客户持仓" },
  { key: "/invite-codes", icon: <GiftOutlined />, label: "邀请码" },
  { key: "/business-orders", icon: <StockOutlined />, label: "客户订单" },
  { key: "/business-trades", icon: <TransactionOutlined />, label: "客户成交" },
  { key: "/business-institutional", icon: <StockOutlined />, label: "Inst. 管理" },
  { key: "/business-otc", icon: <BankOutlined />, label: "OTC 审核" },
];
const businessItemsEn: MenuItem[] = [
  { key: "/dashboard", icon: <DashboardOutlined />, label: "Business Overview" },
  { key: "/business-customers", icon: <TeamOutlined />, label: "Customers" },
  { key: "/business-accounts", icon: <BankOutlined />, label: "Accounts" },
  { key: "/business-funds", icon: <DollarOutlined />, label: "Funds" },
  { key: "/business-kyc", icon: <SafetyCertificateOutlined />, label: "KYC Review" },
  { key: "/business-ipo", icon: <WarningOutlined />, label: "IPO Allocation" },
  { key: "/business-positions", icon: <StockOutlined />, label: "Positions" },
  { key: "/invite-codes", icon: <GiftOutlined />, label: "Invite Codes" },
  { key: "/business-orders", icon: <StockOutlined />, label: "Customer Orders" },
  { key: "/business-trades", icon: <TransactionOutlined />, label: "Customer Trades" },
  { key: "/business-institutional", icon: <StockOutlined />, label: "Inst. Management" },
  { key: "/business-otc", icon: <BankOutlined />, label: "OTC Review" },
];
const roleMeta: Record<string, { label: string; product: string; color: string }> = {
  ADMIN: { label: "管理员", product: "管理后台", color: "purple" },
  FINANCE: { label: "财务", product: "财务后台", color: "gold" },
  SUPPORT: { label: "客服", product: "客服后台", color: "blue" },
  BUSINESS: { label: "业务员", product: "业务后台", color: "green" },
};

export default function AdminShell({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const [mobile, setMobile] = useState(false);
  const [drawer, setDrawer] = useState(false);
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [language, setLanguage] = useState<"zh" | "en">("zh");

  useEffect(() => {
    const sync = () => setMobile(window.innerWidth < 900);
    sync(); window.addEventListener("resize", sync);
    return () => window.removeEventListener("resize", sync);
  }, []);
  useEffect(() => {
    const token = localStorage.getItem("adminAccessToken");
    const stored = localStorage.getItem("adminUser");
    if (!token) { router.replace("/login"); return; }
    try { if (stored) setUser(JSON.parse(stored)); }
    catch { localStorage.removeItem("adminUser"); router.replace("/login"); }
  }, [router]);
  useEffect(() => {
    const saved = localStorage.getItem("businessLanguage");
    if (saved === "en") setLanguage("en");
  }, []);

  const items = useMemo(() => user?.role === "BUSINESS" ? (language === "en" ? businessItemsEn : businessItems) : user?.role === "FINANCE" ? financeItems : user?.role === "SUPPORT" ? supportItems : adminItems, [user?.role, language]);
  const meta = roleMeta[user?.role || "ADMIN"] || roleMeta.ADMIN;
  const pageTitle = items.find((item) => item.key === pathname)?.label || "工作台";
  const logout = () => { localStorage.removeItem("adminAccessToken"); localStorage.removeItem("adminUser"); router.replace("/login"); };
  const switchLanguage = () => {
    const next = language === "zh" ? "en" : "zh";
    setLanguage(next); localStorage.setItem("businessLanguage", next);
    window.dispatchEvent(new CustomEvent("business-language-change", { detail: next }));
  };
  const menu = <Menu theme="dark" mode="inline" selectedKeys={[pathname]} items={items} onClick={({ key }) => { router.push(key); setDrawer(false); }} className="ops-menu" />;
  const brand = <div className="ops-brand"><span className="ops-logo"><StockOutlined /></span>{!collapsed && <div><strong>India Trading</strong><small>{meta.product}</small></div>}</div>;

  return <Layout className="ops-layout">
    {!mobile && <Sider width={256} collapsedWidth={76} collapsed={collapsed} trigger={null} className="ops-sider">{brand}{menu}</Sider>}
    <Drawer placement="left" width={280} open={mobile && drawer} onClose={() => setDrawer(false)} styles={{ body: { padding: 0, background: "#071426" }, header: { display: "none" } }}>{<div className="ops-mobile-nav"><div className="ops-brand"><span className="ops-logo"><StockOutlined /></span><div><strong>India Trading</strong><small>{meta.product}</small></div></div>{menu}</div>}</Drawer>
    <Layout>
      <Header className="ops-header">
        <Space><Button type="text" aria-label="切换导航" icon={mobile ? <MenuUnfoldOutlined /> : collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />} onClick={() => mobile ? setDrawer(true) : setCollapsed(!collapsed)} /><div className="ops-title"><Text type="secondary">OPERATIONS WORKSPACE</Text><strong>{pageTitle}</strong></div></Space>
        <Space size={mobile ? 8 : 14}>
          {user?.role === "BUSINESS" && <Button size="small" onClick={switchLanguage}>{language === "zh" ? "EN" : "中文"}</Button>}
          <Tag color={meta.color}>{meta.label}</Tag>
          {!mobile && <><Avatar className="ops-avatar">{(user?.fullName || "管").charAt(0)}</Avatar><div className="ops-user"><strong>{user?.fullName || "系统管理员"}</strong><small>安全登录</small></div></>}
          <Button type="text" danger icon={<LogoutOutlined />} onClick={logout}>{mobile ? null : "退出"}</Button>
        </Space>
      </Header>
      <Content className="ops-content">{children}</Content>
    </Layout>
  </Layout>;
}
