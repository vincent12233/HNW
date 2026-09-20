"use client";

import { Space, Typography } from "antd";
import AdminShell from "@/components/AdminShell";
import VipClientsWorkspace from "@/components/VipClientsWorkspace";

const { Title, Paragraph } = Typography;

export default function BusinessVipPage() {
  return (
    <AdminShell>
      <Space direction="vertical" size={16} style={{ width: "100%" }}>
        <div>
          <Title level={3} style={{ marginBottom: 4 }}>我的客户 VIP</Title>
          <Paragraph type="secondary" style={{ marginBottom: 0 }}>
            只能查看和调整分配给自己的客户。建议等级仅供参考，必须填写原因并二次确认后才会改写当前等级。
          </Paragraph>
        </div>
        <VipClientsWorkspace
          endpoint="/business/vip-clients"
          historyEndpoint={(userId) => `/business/vip-clients/${userId}/history`}
          adjustEndpoint={(userId) => `/business/vip-clients/${userId}/tier`}
          allowAdjust
          emptyText="暂无分配给自己的客户"
        />
      </Space>
    </AdminShell>
  );
}
