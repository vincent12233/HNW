"use client";

import { IdcardOutlined, LockOutlined, SafetyCertificateOutlined, StockOutlined } from "@ant-design/icons";
import { Alert, Button, Form, Input } from "antd";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { api } from "@/lib/api";

type Values = { employeeNo: string; password: string };
export default function AdminLoginPage() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  async function submit(values: Values) {
    setError(""); setSubmitting(true);
    try {
      const { data } = await api.post("/auth/login", { employeeNo: values.employeeNo.trim().toUpperCase(), password: values.password });
      if (!["ADMIN", "FINANCE", "BUSINESS", "SUPPORT"].includes(data.user?.role)) { setError("此账号没有后台访问权限。"); return; }
      localStorage.setItem("adminUser", JSON.stringify(data.user));
      const home: Record<string,string> = { ADMIN:"/dashboard", FINANCE:"/deposits", SUPPORT:"/support-console", BUSINESS:"/business-customers" };
      router.push(home[data.user.role] || "/dashboard");
    } catch (e: any) {
      const message=e.response?.data?.message;
      setError(Array.isArray(message)?message.join("，"):message||"登录失败，请检查员工编号、密码或后台服务。");
    } finally { setSubmitting(false); }
  }
  return <main className="admin-login">
    <div className="login-visual">
      <div className="login-brand"><span><StockOutlined /></span><div><strong>India Trading</strong><small>Operations Platform</small></div></div>
      <div><p>SECURE FINANCIAL OPERATIONS</p><h1>统一管理，<br/>清晰掌控每一步。</h1><div className="login-points"><span><SafetyCertificateOutlined /> 权限隔离</span><span>实时业务数据</span><span>完整操作审计</span></div></div>
    </div>
    <section className="login-card">
      <div className="login-mobile-brand"><StockOutlined /> India Trading</div>
      <p className="eyebrow">STAFF ACCESS</p><h2>运营后台登录</h2><p className="subtitle">管理员、财务、业务员和客服使用员工编号登录</p>
      {error && <Alert type="error" title={error} showIcon />}
      <Form<Values> layout="vertical" onFinish={submit} size="large">
        <Form.Item label="员工编号" name="employeeNo" rules={[{required:true,message:"请输入员工编号"}]}><Input prefix={<IdcardOutlined />} placeholder="例如 ADMIN001" autoCapitalize="characters" /></Form.Item>
        <Form.Item label="密码" name="password" rules={[{required:true,message:"请输入密码"},{min:8,message:"密码至少需要 8 个字符"}]}><Input.Password prefix={<LockOutlined />} placeholder="请输入密码" /></Form.Item>
        <Button type="primary" htmlType="submit" loading={submitting} block>{submitting?"安全验证中…":"登录工作台"}</Button>
      </Form>
      <p className="login-foot"><SafetyCertificateOutlined /> 仅限已授权员工访问，所有操作均会记录</p>
    </section>
  </main>;
}
