"use client";

import AdminShell from "@/components/AdminShell";
import OpsOrderWorkspace from "@/components/OpsOrderWorkspace";
import { TRADING_COPY } from "@/lib/ops-trading";

export default function OrdersPage() {
  return (
    <AdminShell>
      <OpsOrderWorkspace
        title={TRADING_COPY.ordersTitle}
        description={TRADING_COPY.ordersDesc}
        crumbs={[{ title: "交易查询" }, { title: TRADING_COPY.ordersTitle }]}
        listApi="/admin/orders"
        searchPlaceholder="搜索客户姓名、交易账号或订单号"
      />
    </AdminShell>
  );
}
