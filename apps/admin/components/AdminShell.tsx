"use client";

import {
  AuditOutlined,
  BankOutlined,
  BarChartOutlined,
  CustomerServiceOutlined,
  DashboardOutlined,
  DollarOutlined,
  GiftOutlined,
  IdcardOutlined,
  LogoutOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  SettingOutlined,
  ShopOutlined,
  StockOutlined,
  TeamOutlined,
  TransactionOutlined,
  UsergroupAddOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Avatar,
  Badge,
  Button,
  Drawer,
  Layout,
  Menu,
  Space,
  Spin,
  Tag,
  Typography,
} from "antd";
import type { ItemType } from "antd/es/menu/interface";
import { usePathname, useRouter } from "next/navigation";
import { ReactNode, useEffect, useMemo, useState } from "react";

import { api } from "@/lib/api";
import { getBackendRole } from "@/lib/backend-role";

const { Header, Sider, Content } = Layout;
const { Text } = Typography;

type Role = "ADMIN" | "MANAGER" | "BUSINESS" | "FINANCE" | "SUPPORT";
type CurrentUser = { id?: string; fullName?: string; phone?: string; role?: Role };
type PendingCounts = {
  kyc: number;
  deposits: number;
  withdrawals: number;
  loans: number;
  otc: number;
  ipo: number;
  approvals: number;
  total: number;
};
type MenuItemDef = {
  key: string;
  icon: ReactNode;
  label: string;
  badge?: keyof PendingCounts;
};
type MenuGroupDef = { title: string; keys: string[] };

const menus: Record<Role, MenuItemDef[]> = {
  ADMIN: [
    { key: "/team", icon: <UsergroupAddOutlined />, label: "管理员管理" },
    { key: "/dashboard", icon: <DashboardOutlined />, label: "管理总览", badge: "total" },
    { key: "/business-users", icon: <UsergroupAddOutlined />, label: "员工与权限" },
    { key: "/customers", icon: <TeamOutlined />, label: "客户总览" },
    { key: "/market", icon: <StockOutlined />, label: "市场运行" },
    { key: "/instruments", icon: <StockOutlined />, label: "股票资料库" },
    { key: "/watchlist", icon: <BarChartOutlined />, label: "Inst. 上架" },
    { key: "/block-trades", icon: <BankOutlined />, label: "OTC 上架" },
    { key: "/ipo-management", icon: <GiftOutlined />, label: "IPO 上架" },
    { key: "/funds", icon: <DollarOutlined />, label: "基金产品" },
    { key: "/quant", icon: <BarChartOutlined />, label: "量化策略" },
    { key: "/orders", icon: <StockOutlined />, label: "订单查询" },
    { key: "/trades", icon: <TransactionOutlined />, label: "成交查询" },
    { key: "/support-console", icon: <CustomerServiceOutlined />, label: "客服会话台" },
    { key: "/app-content", icon: <SettingOutlined />, label: "客户端运营配置" },
    { key: "/company-showcase", icon: <ShopOutlined />, label: "平台公司信息" },
    { key: "/audit-logs", icon: <AuditOutlined />, label: "安全审计" },
  ],
  MANAGER: [
    { key: "/team?view=customers", icon: <TeamOutlined />, label: "客户资料" },
    { key: "/team?view=deposits", icon: <DollarOutlined />, label: "客户入金", badge: "deposits" },
    { key: "/team?view=withdrawals", icon: <BankOutlined />, label: "客户提现", badge: "withdrawals" },
    { key: "/team?view=positions", icon: <BarChartOutlined />, label: "客户持仓" },
    { key: "/team?view=orders", icon: <StockOutlined />, label: "客户订单" },
    { key: "/team?view=trades", icon: <TransactionOutlined />, label: "客户成交" },
    { key: "/team?view=kyc", icon: <IdcardOutlined />, label: "KYC 审核", badge: "kyc" },
    { key: "/team?view=team", icon: <UsergroupAddOutlined />, label: "我的业务员" },
  ],
  BUSINESS: [
    { key: "/dashboard", icon: <DashboardOutlined />, label: "业务总览", badge: "total" },
    { key: "/business-customers", icon: <TeamOutlined />, label: "我的客户" },
    { key: "/business-kyc", icon: <IdcardOutlined />, label: "KYC 审核", badge: "kyc" },
    { key: "/business-accounts", icon: <BankOutlined />, label: "客户账户" },
    { key: "/business-deposits", icon: <DollarOutlined />, label: "我的客户入金记录" },
    { key: "/business-withdrawals", icon: <BankOutlined />, label: "我的客户提现记录" },
    { key: "/loans", icon: <DollarOutlined />, label: "客户贷款" },
    { key: "/business-otc", icon: <TransactionOutlined />, label: "OTC 审核", badge: "otc" },
    { key: "/business-ipo", icon: <GiftOutlined />, label: "IPO 分配" },
    { key: "/business-positions", icon: <BarChartOutlined />, label: "客户持仓" },
    { key: "/business-orders", icon: <StockOutlined />, label: "客户订单" },
    { key: "/business-trades", icon: <TransactionOutlined />, label: "客户成交" },
  ],
  FINANCE: [
    { key: "/dashboard", icon: <DashboardOutlined />, label: "财务工作台", badge: "total" },
    { key: "/customers", icon: <TeamOutlined />, label: "客户账户" },
    { key: "/finance-overview", icon: <DollarOutlined />, label: "资金调整" },
    { key: "/approvals", icon: <AuditOutlined />, label: "双人复核", badge: "approvals" },
    { key: "/deposits", icon: <DollarOutlined />, label: "入金审核", badge: "deposits" },
    { key: "/withdrawals", icon: <BankOutlined />, label: "提现审核", badge: "withdrawals" },
    { key: "/transactions", icon: <TransactionOutlined />, label: "资金流水" },
    { key: "/bank-accounts", icon: <BankOutlined />, label: "银行账户" },
    { key: "/ipo-debts", icon: <GiftOutlined />, label: "IPO 欠款" },
    { key: "/orders", icon: <StockOutlined />, label: "订单查询" },
    { key: "/trades", icon: <TransactionOutlined />, label: "成交查询" },
    { key: "/loans", icon: <DollarOutlined />, label: "贷款处理", badge: "loans" },
  ],
  SUPPORT: [
    { key: "/dashboard", icon: <DashboardOutlined />, label: "专用运营总览", badge: "total" },
    { key: "/operator-console", icon: <CustomerServiceOutlined />, label: "固定邀请码客户", badge: "total" },
    { key: "/support-console", icon: <CustomerServiceOutlined />, label: "客服会话台" },
    { key: "/business-customers", icon: <TeamOutlined />, label: "客户管理" },
    { key: "/business-funds", icon: <DollarOutlined />, label: "资金管理" },
    { key: "/deposits", icon: <DollarOutlined />, label: "入金审核", badge: "deposits" },
    { key: "/business-deposits", icon: <DollarOutlined />, label: "我的客户入金记录" },
    { key: "/business-withdrawals", icon: <BankOutlined />, label: "我的客户提现记录" },
    { key: "/business-kyc", icon: <IdcardOutlined />, label: "KYC 管理", badge: "kyc" },
    { key: "/business-accounts", icon: <BankOutlined />, label: "客户账户" },
    { key: "/business-institutional", icon: <StockOutlined />, label: "Inst. 业务" },
    { key: "/business-otc", icon: <TransactionOutlined />, label: "OTC 审核", badge: "otc" },
    { key: "/business-ipo", icon: <GiftOutlined />, label: "IPO 分配" },
    { key: "/business-positions", icon: <BarChartOutlined />, label: "客户持仓" },
    { key: "/business-orders", icon: <StockOutlined />, label: "客户订单" },
    { key: "/business-trades", icon: <TransactionOutlined />, label: "客户成交" },
  ],
};

/** Visual grouping only — keys must stay within the role allowlist above. */
const menuGroups: Record<Role, MenuGroupDef[]> = {
  ADMIN: [
    { title: "治理与人员", keys: ["/team", "/dashboard", "/business-users", "/customers", "/audit-logs"] },
    {
      title: "市场与产品",
      keys: ["/market", "/instruments", "/watchlist", "/block-trades", "/ipo-management", "/funds", "/quant"],
    },
    { title: "交易查询", keys: ["/orders", "/trades"] },
    { title: "运营配置", keys: ["/support-console", "/app-content", "/company-showcase"] },
  ],
  MANAGER: [
    {
      title: "客户业务",
      keys: [
        "/team?view=customers",
        "/team?view=deposits",
        "/team?view=withdrawals",
        "/team?view=positions",
        "/team?view=orders",
        "/team?view=trades",
        "/team?view=kyc",
      ],
    },
    { title: "团队", keys: ["/team?view=team"] },
  ],
  BUSINESS: [
    { title: "工作台", keys: ["/dashboard"] },
    { title: "我的客户", keys: ["/business-customers", "/business-kyc", "/business-accounts"] },
    { title: "资金与贷款", keys: ["/business-deposits", "/business-withdrawals", "/loans"] },
    {
      title: "交易业务",
      keys: ["/business-otc", "/business-ipo", "/business-positions", "/business-orders", "/business-trades"],
    },
  ],
  FINANCE: [
    { title: "工作台", keys: ["/dashboard"] },
    { title: "资金审核", keys: ["/deposits", "/withdrawals", "/approvals", "/loans"] },
    {
      title: "账户与流水",
      keys: ["/customers", "/finance-overview", "/transactions", "/bank-accounts", "/ipo-debts"],
    },
    { title: "交易查询", keys: ["/orders", "/trades"] },
  ],
  SUPPORT: [
    { title: "工作台", keys: ["/dashboard", "/operator-console", "/support-console"] },
    {
      title: "客户与资金",
      keys: [
        "/business-customers",
        "/business-funds",
        "/deposits",
        "/business-deposits",
        "/business-withdrawals",
        "/business-kyc",
        "/business-accounts",
      ],
    },
    {
      title: "交易业务",
      keys: [
        "/business-institutional",
        "/business-otc",
        "/business-ipo",
        "/business-positions",
        "/business-orders",
        "/business-trades",
      ],
    },
  ],
};

const roleMeta: Record<Role, { label: string; product: string; color: string }> = {
  ADMIN: { label: "超级管理员", product: "平台治理后台", color: "geekblue" },
  MANAGER: { label: "管理员", product: "客户业务管理后台", color: "cyan" },
  BUSINESS: { label: "业务员", product: "客户业务后台", color: "green" },
  FINANCE: { label: "财务", product: "资金结算后台", color: "gold" },
  SUPPORT: { label: "专用运营员", product: "固定邀请码客户后台", color: "blue" },
};

function emptyPending(): PendingCounts {
  return { kyc: 0, deposits: 0, withdrawals: 0, loans: 0, otc: 0, ipo: 0, approvals: 0, total: 0 };
}

export default function AdminShell({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [activeKey, setActiveKey] = useState(pathname);
  const [collapsed, setCollapsed] = useState(false);
  const [mobile, setMobile] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [verified, setVerified] = useState(false);
  const [pending, setPending] = useState<PendingCounts>(emptyPending());
  const [pendingUnavailable, setPendingUnavailable] = useState(false);

  useEffect(() => {
    const sync = () => setMobile(window.innerWidth < 900);
    sync();
    window.addEventListener("resize", sync);
    return () => window.removeEventListener("resize", sync);
  }, []);

  useEffect(() => {
    let active = true;
    const deploymentRole = getBackendRole();

    const verifySession = async () => {
      let lastError: unknown;
      for (let attempt = 0; attempt < 3; attempt += 1) {
        try {
          const { data } = await api.get<CurrentUser>("/auth/me");
          if (!data.role || !menus[data.role] || (deploymentRole && data.role !== deploymentRole)) {
            throw new Error("Role not allowed on this backend");
          }
          return data;
        } catch (error: any) {
          lastError = error;
          const status = error?.response?.status;
          if (status === 401 || status === 403 || attempt === 2) throw error;
          await new Promise((resolve) => window.setTimeout(resolve, 500 * (attempt + 1)));
        }
      }
      throw lastError;
    };

    verifySession()
      .then((data) => {
        if (!active) return;
        localStorage.setItem("adminUser", JSON.stringify(data));
        setUser(data);
        setVerified(true);
      })
      .catch(() => {
        if (!active) return;
        localStorage.removeItem("adminUser");
        router.replace("/login");
      });

    return () => {
      active = false;
    };
  }, [router]);

  useEffect(() => {
    if (!verified) return;
    let active = true;
    let generation = 0;

    const refresh = async () => {
      const current = ++generation;
      try {
        const { data } = await api.get<PendingCounts>("/admin/pending-counts");
        if (active && current === generation) {
          setPending(data);
          setPendingUnavailable(false);
        }
      } catch {
        if (active && current === generation) setPendingUnavailable(true);
      }
    };

    refresh();
    const timer = window.setInterval(refresh, 30000);
    const onVisible = () => {
      if (document.visibilityState === "visible") refresh();
    };
    window.addEventListener("admin-data-changed", refresh);
    window.addEventListener("focus", refresh);
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      active = false;
      window.clearInterval(timer);
      window.removeEventListener("admin-data-changed", refresh);
      window.removeEventListener("focus", refresh);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [verified]);

  useEffect(() => {
    const syncNavigation = () => setActiveKey(window.location.pathname + window.location.search);
    syncNavigation();
    window.addEventListener("popstate", syncNavigation);
    return () => window.removeEventListener("popstate", syncNavigation);
  }, []);

  const role: Role = user?.role || "ADMIN";
  const flatItems = useMemo(
    () =>
      menus[role].map((item) => ({
        ...item,
        badge: item.key === "/business-ipo" ? ("ipo" as const) : item.badge === "total" ? undefined : item.badge,
      })),
    [role],
  );
  const byKey = useMemo(() => Object.fromEntries(flatItems.map((item) => [item.key, item])), [flatItems]);
  const meta = roleMeta[role];
  const [activePath, query = ""] = activeKey.split("?");
  const selectedItem =
    flatItems.find((item) => {
      const [path, itemQuery] = item.key.split("?");
      if (!activePath.startsWith(path)) return false;
      return itemQuery ? itemQuery === query : !query;
    }) || flatItems.find((item) => activePath.startsWith(item.key.split("?")[0]));
  const pageTitle = selectedItem?.label || "工作台";
  const allowed =
    pathname === "/" ||
    pathname === "/login" ||
    flatItems.some(
      (item) => pathname === item.key.split("?")[0] || pathname.startsWith(`${item.key.split("?")[0]}/`),
    );

  useEffect(() => {
    if (user && !allowed) router.replace(user.role === "MANAGER" ? "/team" : "/dashboard");
  }, [allowed, router, user]);

  const logout = async () => {
    try {
      await api.post("/auth/logout");
    } finally {
      localStorage.removeItem("adminUser");
      router.replace("/login");
    }
  };

  const menuItems: ItemType[] = menuGroups[role].map((group) => ({
    type: "group",
    key: `group-${group.title}`,
    label: collapsed && !mobile ? null : group.title,
    children: group.keys
      .map((key) => byKey[key])
      .filter(Boolean)
      .map((item) => {
        const count = item.badge ? pending[item.badge] || 0 : 0;
        return {
          key: item.key,
          icon: item.icon,
          label:
            count > 0 ? (
              <span className="ops-menu-label">
                <span>{item.label}</span>
                <Badge count={count} overflowCount={99} size="small" />
              </span>
            ) : (
              item.label
            ),
        };
      }),
  }));

  const onMenuClick = ({ key }: { key: string }) => {
    const nextKey = String(key);
    if (nextKey.startsWith("group-")) return;
    setActiveKey(nextKey);
    router.push(nextKey);
    window.dispatchEvent(new CustomEvent("admin-navigation", { detail: nextKey }));
    setDrawerOpen(false);
  };

  const menu = (
    <Menu
      theme="dark"
      mode="inline"
      selectedKeys={[selectedItem?.key || activeKey]}
      items={menuItems}
      onClick={onMenuClick}
      className="ops-menu"
    />
  );

  const brand = (
    <div className="ops-brand">
      <span className="ops-logo">
        <StockOutlined />
      </span>
      {!collapsed && (
        <div>
          <strong>India Trading</strong>
          <small>{meta.product}</small>
        </div>
      )}
    </div>
  );

  if (!verified || !user) {
    return (
      <div className="ops-boot">
        <Spin size="large" tip="正在验证安全会话" />
      </div>
    );
  }

  return (
    <Layout className={`ops-layout role-${role.toLowerCase()}`}>
      {pendingUnavailable && (
        <div className="ops-pending-warn">
          <Alert
            type="warning"
            showIcon
            title="待办数量暂未更新，请勿将角标视为最新结果"
            action={
              <Button size="small" onClick={() => window.dispatchEvent(new CustomEvent("admin-data-changed"))}>
                重试
              </Button>
            }
          />
        </div>
      )}

      {!mobile && (
        <Sider width={264} collapsedWidth={78} collapsed={collapsed} trigger={null} className="ops-sider">
          {brand}
          {menu}
        </Sider>
      )}

      <Drawer
        placement="left"
        width={292}
        open={mobile && drawerOpen}
        onClose={() => setDrawerOpen(false)}
        styles={{ body: { padding: 0, background: "#071426" }, header: { display: "none" } }}
      >
        <div className="ops-mobile-nav">
          {brand}
          {menu}
        </div>
      </Drawer>

      <Layout>
        <Header className="ops-header">
          <Space size={12}>
            <Button
              type="text"
              aria-label="切换导航"
              className="ops-nav-toggle"
              icon={mobile || collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
              onClick={() => (mobile ? setDrawerOpen(true) : setCollapsed((value) => !value))}
            />
            <div className="ops-title">
              <Text type="secondary">OPERATIONS WORKSPACE</Text>
              <strong>{pageTitle}</strong>
            </div>
          </Space>
          <Space size={mobile ? 8 : 14}>
            <Tag color={meta.color} className="ops-role-tag">
              {meta.label}
            </Tag>
            {!mobile && (
              <>
                <Avatar className="ops-avatar">{(user.fullName || "管").charAt(0)}</Avatar>
                <div className="ops-user">
                  <strong>{user.fullName || meta.label}</strong>
                  <small>权限已隔离 · 安全登录</small>
                </div>
              </>
            )}
            <Button type="text" danger icon={<LogoutOutlined />} onClick={logout}>
              {mobile ? null : "退出"}
            </Button>
          </Space>
        </Header>
        <Content className="ops-content">{verified && allowed ? children : null}</Content>
      </Layout>
    </Layout>
  );
}
