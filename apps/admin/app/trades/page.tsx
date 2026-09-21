"use client";

import AdminShell from "@/components/AdminShell";
import OpsTradeWorkspace from "@/components/OpsTradeWorkspace";
import { TRADING_COPY } from "@/lib/ops-trading";

export default function TradesPage() {
  return (
    <AdminShell>
      <OpsTradeWorkspace
        title={TRADING_COPY.tradesTitle}
        description={TRADING_COPY.tradesDesc}
        crumbs={[{ title: "交易查询" }, { title: TRADING_COPY.tradesTitle }]}
        listApi="/admin/trades"
        searchPlaceholder="搜索成交号、订单号、客户姓名或交易账号"
      />
    </AdminShell>
  );
}
