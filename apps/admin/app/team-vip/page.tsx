"use client";

import { Space, Typography } from "antd";
import AdminShell from "@/components/AdminShell";
import VipClientsWorkspace from "@/components/VipClientsWorkspace";

const { Title, Paragraph } = Typography;

export default function TeamVipPage() {
  return (
    <AdminShell>
      <Space direction="vertical" size={16} style={{ width: "100%" }}>
        <div>
          <Title level={3} style={{ marginBottom: 4 }}>团队 VIP 客户</Title>
          <Paragraph type="secondary" style={{ marginBottom: 0 }}>
            只读查看自己名下业务员的客户 VIP 等级、累计充值和建议等级。不能配置门槛，也不能调整客户等级。
          </Paragraph>
        </div>
        <VipClientsWorkspace
          endpoint="/team/vip-clients"
          historyEndpoint={(userId) => `/team/vip-clients/${userId}/history`}
          emptyText="当前团队暂无客户 VIP 数据"
          showBusinessBreakdown
        />
      </Space>
    </AdminShell>
  );
}
