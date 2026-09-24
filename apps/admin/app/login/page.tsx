"use client";

import { EyeInvisibleOutlined, EyeOutlined, IdcardOutlined, LockOutlined, LoginOutlined, SafetyCertificateOutlined } from "@ant-design/icons";
import { Alert, Button, Form, Input } from "antd";
import { isAxiosError } from "axios";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";

import { api } from "@/lib/api";
import { backendRoleLabels, getBackendRole, type BackendRole } from "@/lib/backend-role";

type Values = { employeeNo: string; password: string };

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

function SessionStatus() {
  const params = useSearchParams();
  if (params.get("session") !== "expired") return null;
  return (
    <div role="status">
      <Alert type="warning" showIcon title="登录已失效，请使用员工编号和密码重新登录。" />
    </div>
  );
}

export default function AdminLoginPage() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const submittingRef = useRef(false);
  const [capsLock, setCapsLock] = useState(false);
  const [deploymentRole, setDeploymentRole] = useState<BackendRole | undefined>(() => getBackendRole());

  useEffect(() => {
    setDeploymentRole(getBackendRole());
  }, []);

  async function submit(values: Values) {
    if (submittingRef.current) return;
    submittingRef.current = true;
    setError("");
    setSubmitting(true);
    try {
      const { data } = await api.post(
        "/auth/login",
        { employeeNo: values.employeeNo.trim().toUpperCase(), password: values.password },
        { timeout: 20000 },
      );
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
      const status = isAxiosError(err) ? err.response?.status : undefined;
      setError(
        isAxiosError(err) && !err.response
          ? "暂时无法连接后台服务，请检查网络后重试。"
          : status === 401
            ? "登录已失效或凭据无效，请重新输入员工编号和密码。"
            : Array.isArray(message) ? message.join("，") : message || "登录失败，请检查员工编号、密码或后台服务。",
      );
    } finally {
      submittingRef.current = false;
      setSubmitting(false);
    }
  }

  const roleClass = deploymentRole ? `role-${deploymentRole.toLowerCase()}` : "";
  const roleTitle = deploymentRole ? backendRoleLabels[deploymentRole] : "员工工作台";

  return (
    <main className={`admin-login ${roleClass}`.trim()}>
      <section className="login-card" aria-labelledby="staff-login-title">
        <div className="login-brand-row">
          <p className="login-brand-mark">HNW</p>
          <p className="login-role-context">
            <SafetyCertificateOutlined aria-hidden />
            {deploymentRole ? backendRoleLabels[deploymentRole] : "安全员工入口"}
          </p>
        </div>
        <p className="eyebrow">员工工作台</p>
        <h1 id="staff-login-title">{roleTitle}</h1>
        <p className="subtitle">
          {deploymentRole
            ? `${roleHints[deploymentRole]}。请使用本角色员工编号登录，跨角色账号将被拒绝。`
            : "请使用员工编号和密码登录对应工作台。"}
        </p>
        {error && (
          <div role="alert">
            <Alert type="error" title={error} showIcon />
          </div>
        )}
        <Suspense fallback={null}>
          <SessionStatus />
        </Suspense>
        <Form<Values>
          layout="vertical"
          onFinish={submit}
          size="large"
          disabled={submitting}
          requiredMark={false}
          aria-busy={submitting}
        >
          <Form.Item label="员工编号" name="employeeNo" rules={[{ required: true, whitespace: true, message: "请输入员工编号" }]}>
            <Input
              prefix={<IdcardOutlined />}
              autoCapitalize="characters"
              autoComplete="username"
              spellCheck={false}
              aria-label="员工编号"
            />
          </Form.Item>
          <Form.Item
            label="密码"
            name="password"
            rules={[
              { required: true, message: "请输入密码" },
              { min: 6, message: "密码至少需要 6 个字符" },
            ]}
          >
            <Input.Password
              prefix={<LockOutlined />}
              autoComplete="current-password"
              aria-label="密码"
              iconRender={(visible) => (visible ? <EyeOutlined /> : <EyeInvisibleOutlined />)}
              onKeyDown={(event) => setCapsLock(event.getModifierState("CapsLock"))}
              onKeyUp={(event) => setCapsLock(event.getModifierState("CapsLock"))}
              onBlur={() => setCapsLock(false)}
              aria-describedby={capsLock ? "login-caps-warning" : undefined}
            />
          </Form.Item>
          {capsLock && (
            <p id="login-caps-warning" className="login-caps-warning" role="status">
              大写锁定已开启
            </p>
          )}
          <Button
            type="primary"
            htmlType="submit"
            loading={submitting}
            icon={submitting ? undefined : <LoginOutlined />}
            block
            className="login-submit"
            style={{ width: "100%", height: 48 }}
          >
            {submitting ? "正在登录…" : "登录工作台"}
          </Button>
        </Form>
        <p className="login-foot">仅限已授权员工使用本入口。客户请使用移动端账户登录。</p>
      </section>
    </main>
  );
}
