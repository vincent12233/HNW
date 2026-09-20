"use client";

import { Space, Typography } from "antd";
import AdminShell from "@/components/AdminShell";
import VipClientsWorkspace from "@/components/VipClientsWorkspace";

const { Title, Paragraph } = Typography;

export default function VipClientsPage() {
  return (
    <AdminShell>
      <Space direction="vertical" size={16} style={{ width: "100%" }}>
        <div>
          <Title level={3} style={{ marginBottom: 4 }}>VIP 客户总览</Title>
          <Paragraph type="secondary" style={{ marginBottom: 0 }}>
            查看全部客户当前等级、累计确认充值和建议等级。建议不会自动改写客户等级，也不影响交易或资金。
          </Paragraph>
        </div>
        <VipClientsWorkspace
          endpoint="/admin/vip-clients"
          historyEndpoint={(userId) => `/admin/vip-clients/${userId}/history`}
          emptyText="暂无客户 VIP 数据"
          showAdminLinks
        />
      </Space>
    </AdminShell>
  );
}
