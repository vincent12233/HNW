"use client";

import { Space } from "antd";
import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";
import VipClientsWorkspace from "@/components/VipClientsWorkspace";

export default function TeamVipPage() {
  return (
    <AdminShell>
      <Space orientation="vertical" size={16} style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title="团队 VIP 客户"
          crumbs={[{ title: "团队" }, { title: "团队 VIP 客户" }]}
          description="只读查看自己名下业务员的客户 VIP 等级、累计充值和建议等级。不能配置门槛，也不能调整客户等级。VIP 没有特殊交易或资金规则。"
        />
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
