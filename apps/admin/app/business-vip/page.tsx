"use client";

import { Space } from "antd";
import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";
import VipClientsWorkspace from "@/components/VipClientsWorkspace";

export default function BusinessVipPage() {
  return (
    <AdminShell>
      <Space orientation="vertical" size={16} style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title="我的客户 VIP"
          crumbs={[{ title: "我的客户" }, { title: "我的客户 VIP" }]}
          description="只能查看和调整分配给自己的客户。建议等级仅供参考，必须填写原因并二次确认后才会改写当前等级。VIP 调整只改当前等级字段，不改变交易或资金规则。"
        />
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
