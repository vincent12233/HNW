"use client";

import AdminShell from "@/components/AdminShell";
import OpsPageHeader from "@/components/OpsPageHeader";
import ReconciliationWorkspace from "@/components/ReconciliationWorkspace";
import { Space } from "antd";

export default function ReconciliationPage() {
  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          title="财务对账"
          crumbs={[{ title: "系统治理" }, { title: "财务对账" }]}
          description="只读核对现金、流水、冻结资产、订单与成交。确认异常只记录处理进度，不会修改客户余额或持仓。"
        />
        <ReconciliationWorkspace />
      </Space>
    </AdminShell>
  );
}
