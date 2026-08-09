"use client";

import { IdcardOutlined, LockOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Form, Input, Typography } from "antd";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { api } from "@/lib/api";

const { Title, Text } = Typography;

type LoginFormValues = {
  employeeNo: string;
  password: string;
};

export default function AdminLoginPage() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleLogin(values: LoginFormValues) {
    setError("");
    setSubmitting(true);

    try {
      const response = await api.post("/auth/login", {
        employeeNo: values.employeeNo.trim().toUpperCase(),
        password: values.password,
      });
      const data = response.data;

      const allowedRoles = ["ADMIN", "FINANCE", "BUSINESS", "SUPPORT"];

      if (!allowedRoles.includes(data.user?.role)) {
        setError("该账号没有后台访问权限。");
        return;
      }

      localStorage.setItem("adminAccessToken", data.accessToken);
      localStorage.setItem("adminUser", JSON.stringify(data.user));

      const roleHome: Record<string, string> = {
        ADMIN: "/dashboard",
        FINANCE: "/deposits",
        SUPPORT: "/support-console",
        BUSINESS: "/business-customers",
      };

      router.push(roleHome[data.user?.role] ?? "/dashboard");
    } catch (requestError: any) {
      const message = requestError.response?.data?.message;

      if (Array.isArray(message)) {
        setError(message.join("，"));
      } else {
        setError(message || "登录失败，请检查员工编号、密码或后台服务。");
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        padding: 24,
        background: "#f3f5f8",
      }}
    >
      <Card
        style={{
          width: "100%",
          maxWidth: 420,
          boxShadow: "0 12px 40px rgba(0,0,0,0.08)",
        }}
      >
        <Title level={2} style={{ marginBottom: 4 }}>
          HNW 运营后台
        </Title>

        <Text type="secondary">请使用内部员工编号登录。</Text>

        {error && (
          <Alert type="error" title={error} showIcon style={{ marginTop: 16 }} />
        )}

        <Form<LoginFormValues>
          layout="vertical"
          onFinish={handleLogin}
          style={{ marginTop: 24 }}
        >
          <Form.Item
            label="员工编号"
            name="employeeNo"
            rules={[{ required: true, message: "请输入员工编号" }]}
          >
            <Input prefix={<IdcardOutlined />} placeholder="例如 ADMIN001" size="large" />
          </Form.Item>

          <Form.Item
            label="密码"
            name="password"
            rules={[
              { required: true, message: "请输入密码" },
              { min: 8, message: "密码至少需要 8 个字符" },
            ]}
          >
            <Input.Password
              prefix={<LockOutlined />}
              placeholder="请输入密码"
              size="large"
            />
          </Form.Item>

          <Button type="primary" htmlType="submit" size="large" loading={submitting} block>
            登录
          </Button>
        </Form>
      </Card>
    </main>
  );
}
