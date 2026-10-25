"use client";

import Link from "next/link";
import { Card, Col, Row, Space, Typography } from "antd";
import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";

const { Text, Title } = Typography;

const modules = [
  { title: "安全审计", description: "检查人员操作、对象和脱敏元数据。", href: "/audit-logs" },
  { title: "系统健康", description: "查看 API、数据库、行情和交易时段探针。", href: "/system-health" },
  { title: "部署状态", description: "核对当前版本、提交与构建时间。", href: "/system-deployments" },
] as const;

export default function SystemGovernancePage() {
  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          title="系统治理"
          crumbs={[{ title: "系统治理" }]}
          description="统一进入只读治理模块。此处不提供服务器终端、密钥、部署或回滚按钮。"
        />
        <Row gutter={[16, 16]}>
          {modules.map((module) => (
            <Col xs={24} md={12} xl={8} key={module.href}>
              <Card className="ops-system-card">
                <Space orientation="vertical" size="small">
                  <Title level={4}>{module.title}</Title>
                  <Text type="secondary">{module.description}</Text>
                  <Link href={module.href}>打开只读视图</Link>
                </Space>
              </Card>
            </Col>
          ))}
        </Row>
      </Space>
    </AdminShell>
  );
}
