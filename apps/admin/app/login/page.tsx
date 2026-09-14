"use client";

import { IdcardOutlined, LockOutlined, SafetyCertificateOutlined, StockOutlined } from "@ant-design/icons";
import { Alert, Button, Form, Input } from "antd";
import { useRouter } from "next/navigation";
import { useState, useSyncExternalStore } from "react";

import { api } from "@/lib/api";
import { backendRoleLabels, getBackendRole, type BackendRole } from "@/lib/backend-role";

type Values = { employeeNo: string; password: string };

const subscribeToBackendRole = () => () => undefined;
const serverBackendRole = () => undefined;

const roleHints: Record<BackendRole, string> = {
  ADMIN: "平台治理、产品上架、权限与审计",
  MANAGER: "客户资料、团队业务员与业务审核",
  FINANCE: "客户存款后创建上分、单人上下分、提现审核",
  BUSINESS: "名下客户、KYC 与业务跟进",
  SUPPORT: "固定邀请码客户与专用客服运营",
};

const homeByRole: Record<string, string> = {
  ADMIN: "/dashboard",
  MANAGER: "/team",
  FINANCE: "/dashboard",
  BUSINESS: "/dashboard",
  SUPPORT: "/dashboard",
};

export default function AdminLoginPage() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const deploymentRole = useSyncExternalStore<BackendRole | undefined>(
    subscribeToBackendRole,
    getBackendRole,
    serverBackendRole,
  );

  async function submit(values: Values) {
    setError("");
    setSubmitting(true);
    try {
      const { data } = await api.post("/auth/login", {
        employeeNo: values.employeeNo.trim().toUpperCase(),
        password: values.password,
      });
      if (
        !["ADMIN", "MANAGER", "FINANCE", "BUSINESS", "SUPPORT"].includes(data.user?.role) ||
        (deploymentRole && data.user?.role !== deploymentRole)
      ) {
        setError(deploymentRole ? `此入口仅允许${backendRoleLabels[deploymentRole]}登录。` : "此账号没有后台访问权限。");
        return;
      }
      localStorage.setItem("adminUser", JSON.stringify(data.user));
      router.push(homeByRole[data.user.role] || "/dashboard");
    } catch (err: unknown) {
      const message = (err as { response?: { data?: { message?: string | string[] } } }).response?.data?.message;
      setError(Array.isArray(message) ? message.join("，") : message || "登录失败，请检查员工编号、密码或后台服务。");
    } finally {
      setSubmitting(false);
    }
  }

  const roleClass = deploymentRole ? `role-${deploymentRole.toLowerCase()}` : "";

  return (
    <main className={`admin-login ${roleClass}`.trim()}>
      <div className="login-visual">
        <div className="login-brand">
          <span>
            <StockOutlined />
          </span>
          <div>
            <strong>India Trading</strong>
            <small>Operations Platform</small>
          </div>
        </div>
        <div>
          <p>SECURE FINANCIAL OPERATIONS</p>
          <h1>
            统一管理，
            <br />
            清晰掌控每一步。
          </h1>
          <div className="login-points">
            <span>
              <SafetyCertificateOutlined /> 权限隔离
            </span>
            <span>五角色独立入口</span>
            <span>完整操作审计</span>
          </div>
        </div>
      </div>

      <section className="login-card">
        <div className="login-mobile-brand">
          <StockOutlined /> India Trading
        </div>
        <p className="eyebrow">STAFF ACCESS</p>
        <h2>{deploymentRole ? backendRoleLabels[deploymentRole] : "运营后台登录"}</h2>
        <p className="subtitle">
          {deploymentRole
            ? `${roleHints[deploymentRole]}。请使用本角色员工编号登录，跨角色账号将被拒绝。`
            : "超级管理员、管理员、财务、业务员与专用运营员使用员工编号登录对应入口。"}
        </p>
        {error && <Alert type="error" title={error} showIcon />}
        <Form<Values> layout="vertical" onFinish={submit} size="large">
          <Form.Item label="员工编号" name="employeeNo" rules={[{ required: true, message: "请输入员工编号" }]}>
            <Input prefix={<IdcardOutlined />} placeholder="例如 ADMIN001" autoCapitalize="characters" />
          </Form.Item>
          <Form.Item
            label="密码"
            name="password"
            rules={[
              { required: true, message: "请输入密码" },
              { min: 6, message: "密码至少需要 6 个字符" },
            ]}
          >
            <Input.Password prefix={<LockOutlined />} placeholder="请输入密码" />
          </Form.Item>
          <Button type="primary" htmlType="submit" loading={submitting} block>
            {submitting ? "安全验证中…" : "登录工作台"}
          </Button>
        </Form>
        <p className="login-foot">
          <SafetyCertificateOutlined /> 仅限已授权员工访问，角色权限严格隔离，所有操作均会记录
        </p>
      </section>
    </main>
  );
}
