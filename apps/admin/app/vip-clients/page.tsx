"use client";

import { Space } from "antd";
import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";
import VipClientsWorkspace from "@/components/VipClientsWorkspace";

export default function VipClientsPage() {
  return (
    <AdminShell>
      <Space direction="vertical" size={16} style={{ width: "100%" }} className="ops-workspace">
        <OpsPageHeader
          title="VIP 客户总览"
          crumbs={[{ title: "治理与人员" }, { title: "VIP 客户总览" }]}
          description="查看全部客户当前等级、累计确认充值和建议等级。建议不会自动改写客户等级，也不影响交易或资金。VIP 只作为普通等级字段。"
        />
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
