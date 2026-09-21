"use client";

import AdminShell from "@/components/AdminShell";
import OpsOrderWorkspace from "@/components/OpsOrderWorkspace";
import { TRADING_COPY } from "@/lib/ops-trading";

export default function BusinessOrdersPage() {
  return (
    <AdminShell>
      <OpsOrderWorkspace
        title={TRADING_COPY.businessOrdersTitle}
        description={TRADING_COPY.businessOrdersDesc}
        crumbs={[{ title: "交易业务" }, { title: TRADING_COPY.businessOrdersTitle }]}
        listApi="/business/my-orders"
        searchPlaceholder="搜索客户、手机号、客户编号、交易账号、订单号或股票"
      />
    </AdminShell>
  );
}
