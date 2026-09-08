"use client";

import { AuditOutlined, BankOutlined, BarChartOutlined, CustomerServiceOutlined, DashboardOutlined, DollarOutlined, GiftOutlined, IdcardOutlined, LogoutOutlined, MenuFoldOutlined, MenuUnfoldOutlined, StockOutlined, TeamOutlined, TransactionOutlined, UsergroupAddOutlined } from "@ant-design/icons";
import { Avatar, Button, Drawer, Layout, Menu, Space, Spin, Tag, Typography } from "antd";
import { usePathname, useRouter } from "next/navigation";
import { ReactNode, useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api";
import { getBackendRole } from "@/lib/backend-role";

const { Header, Sider, Content } = Layout;
const { Text } = Typography;
type Role = "ADMIN" | "MANAGER" | "BUSINESS" | "FINANCE" | "SUPPORT";
type CurrentUser = { id?: string; fullName?: string; phone?: string; role?: Role };
type MenuItem = { key: string; icon: ReactNode; label: string };
const menus: Record<Role, MenuItem[]> = {
  ADMIN: [
    { key: "/team", icon: <UsergroupAddOutlined />, label: "管理员管理" },
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
  MANAGER: [
    { key: "/team?view=customers", icon: <TeamOutlined />, label: "客户资料" },
    { key: "/team?view=deposits", icon: <DollarOutlined />, label: "客户入金" },
    { key: "/team?view=withdrawals", icon: <BankOutlined />, label: "客户提现" },
    { key: "/team?view=positions", icon: <BarChartOutlined />, label: "客户持仓" },
    { key: "/team?view=orders", icon: <StockOutlined />, label: "客户订单" },
    { key: "/team?view=trades", icon: <TransactionOutlined />, label: "客户成交" },
    { key: "/team?view=kyc", icon: <IdcardOutlined />, label: "KYC 审核" },
    { key: "/team?view=team", icon: <UsergroupAddOutlined />, label: "我的业务员" },
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
    { key: "/approvals", icon: <AuditOutlined />, label: "双人复核" },
    { key: "/deposits", icon: <DollarOutlined />, label: "入金审核" },
    { key: "/withdrawals", icon: <BankOutlined />, label: "提现审核" },
    { key: "/transactions", icon: <TransactionOutlined />, label: "资金流水" },
    { key: "/bank-accounts", icon: <BankOutlined />, label: "银行账户" },
    { key: "/loans", icon: <DollarOutlined />, label: "贷款处理" },
  ],
  SUPPORT: [
    { key: "/operator-console", icon: <CustomerServiceOutlined />, label: "固定邀请码客户" },
  ],
};

const roleMeta: Record<Role, { label: string; product: string; color: string }> = {
  ADMIN: { label: "超级管理员", product: "平台治理后台", color: "purple" },
  MANAGER: { label: "管理员", product: "客户业务管理后台", color: "cyan" },
  BUSINESS: { label: "业务员", product: "客户业务后台", color: "green" },
  FINANCE: { label: "财务", product: "资金结算后台", color: "gold" },
  SUPPORT: { label: "专用运营员", product: "固定邀请码客户后台", color: "blue" },
};

export default function AdminShell({ children }: { children: ReactNode }) {
  const router = useRouter(); const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false); const [mobile, setMobile] = useState(false); const [drawer, setDrawer] = useState(false); const [user, setUser] = useState<CurrentUser | null>(null); const [verified, setVerified] = useState(false);
  useEffect(() => { const sync = () => setMobile(window.innerWidth < 900); sync(); window.addEventListener("resize", sync); return () => window.removeEventListener("resize", sync); }, []);
  useEffect(() => { let active=true; const deploymentRole = getBackendRole(); api.get<CurrentUser>("/auth/me").then(({data})=>{if(!active)return;if(!data.role||!menus[data.role]||(deploymentRole && data.role !== deploymentRole))throw new Error("Role not allowed on this backend");localStorage.setItem("adminUser",JSON.stringify(data));setUser(data);setVerified(true);}).catch(()=>{if(!active)return;localStorage.removeItem("adminUser");router.replace("/login");});return()=>{active=false;}; }, [router]);
  const role: Role = user?.role || "ADMIN"; const items = useMemo(() => menus[role], [role]); const meta = roleMeta[role];
  const pageTitle = items.find((item) => pathname.startsWith(item.key.split("?")[0]))?.label || "工作台";
  const allowed = pathname === "/" || pathname === "/login" || items.some((item) => pathname.startsWith(item.key.split("?")[0]));
  useEffect(() => { if (user && !allowed) router.replace(user.role === "MANAGER" ? "/team" : "/dashboard"); }, [allowed, router, user]);
  const logout = async () => { try { await api.post("/auth/logout"); } finally { localStorage.removeItem("adminUser"); router.replace("/login"); } };
  const menu = <Menu theme="dark" mode="inline" selectedKeys={[items.find((item) => pathname.startsWith(item.key.split("?")[0]))?.key || pathname]} items={items} onClick={({ key }) => { router.push(key); setDrawer(false); }} className="ops-menu" />;
  const brand = <div className="ops-brand"><span className="ops-logo"><StockOutlined /></span>{!collapsed && <div><strong>India Trading</strong><small>{meta.product}</small></div>}</div>;
  if (!verified || !user) return <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "#f4f7fb" }}><Spin size="large" tip="正在验证安全会话" /></div>;
  return <Layout className={`ops-layout role-${role.toLowerCase()}`}>
    {!mobile && <Sider width={256} collapsedWidth={76} collapsed={collapsed} trigger={null} className="ops-sider">{brand}{menu}</Sider>}
    <Drawer placement="left" width={280} open={mobile && drawer} onClose={() => setDrawer(false)} styles={{ body: { padding: 0, background: "#071426" }, header: { display: "none" } }}><div className="ops-mobile-nav">{brand}{menu}</div></Drawer>
    <Layout><Header className="ops-header"><Space><Button type="text" aria-label="切换导航" icon={mobile || collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />} onClick={() => mobile ? setDrawer(true) : setCollapsed(!collapsed)} /><div className="ops-title"><Text type="secondary">OPERATIONS WORKSPACE</Text><strong>{pageTitle}</strong></div></Space><Space size={mobile ? 8 : 14}><Tag color={meta.color}>{meta.label}</Tag>{!mobile && <><Avatar className="ops-avatar">{(user?.fullName || "管").charAt(0)}</Avatar><div className="ops-user"><strong>{user?.fullName || meta.label}</strong><small>安全登录</small></div></>}<Button type="text" danger icon={<LogoutOutlined />} onClick={logout}>{mobile ? null : "退出"}</Button></Space></Header><Content className="ops-content">{verified && allowed ? children : null}</Content></Layout>
  </Layout>;
}

