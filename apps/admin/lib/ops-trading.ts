/** Display helpers for admin order/trade consoles. No trading or ledger semantics. */

export const ORDER_STATUSES = [
  "PENDING",
  "OPEN",
  "PARTIALLY_FILLED",
  "FILLED",
  "CANCELLED",
  "REJECTED",
] as const;

export const ORDER_SIDES = ["BUY", "SELL"] as const;
export const ORDER_TYPES = ["MARKET", "LIMIT"] as const;
export const ORDER_TIFS = ["DAY", "IOC", "FOK"] as const;

export const ORDER_STATUS_FILTER_OPTIONS = ORDER_STATUSES.map((value) => ({
  value,
  label:
    value === "CANCELLED"
      ? "已撤单"
      : value === "PENDING"
        ? "待报"
        : value === "OPEN"
          ? "挂单中"
          : value === "PARTIALLY_FILLED"
            ? "部分成交"
            : value === "FILLED"
              ? "已成交"
              : "已拒绝",
}));

export function orderStatusLabel(status?: string | null) {
  if (status === "CANCELLED") return "已撤单";
  if (status === "PENDING") return "待报";
  return undefined;
}

export function tradeFeeOf(record: { feeAmount?: string | number | null; fees?: string | number | null }) {
  return record.feeAmount ?? record.fees ?? null;
}

export const TRADING_COPY = {
  ordersTitle: "订单查询",
  businessOrdersTitle: "客户订单记录",
  tradesTitle: "成交查询",
  pairsTitle: "客户交易配对记录",
  ordersDesc:
    "查看客户买入、卖出和成交状态。筛选由服务端执行。本页不提供撤单或改单，状态只在接口返回后更新。",
  businessOrdersDesc:
    "只显示当前业务员或专用运营员名下客户的订单。不能查看其他业务员客户，也不能撤单。",
  tradesDesc: "查看客户实际成交。费用和净额使用接口返回值，不在前端重算成交、持仓或盈亏。",
  pairsDesc:
    "买入与卖出按接口返回的 FIFO 配对显示。未卖出数量显示为持仓中。搜索只作用于已加载结果。",
  noCancel: "后台订单页不提供撤单或改单。客户仍使用现有客户端撤单接口。",
  tradesFromApi: "成交明细仅展示当前接口返回的记录，不编造未返回的成交。",
  feeZero: "当前费用按接口返回展示；系统费用为 0 时显示 ₹0.00。",
  loadedFilter: "以下搜索只作用于已经加载的配对结果，不是新的服务端查询。",
};

export type TradingRoleWorkflow = {
  role: string;
  ordersPage: string | null;
  ordersApi: string | null;
  tradesPage: string | null;
  tradesApi: string | null;
};

export function tradingWorkflowForRole(role: string): TradingRoleWorkflow {
  if (role === "ADMIN" || role === "FINANCE") {
    return {
      role,
      ordersPage: "/orders",
      ordersApi: "/admin/orders",
      tradesPage: "/trades",
      tradesApi: "/admin/trades",
    };
  }
  if (role === "BUSINESS" || role === "SUPPORT") {
    return {
      role,
      ordersPage: "/business-orders",
      ordersApi: "/business/my-orders",
      tradesPage: "/business-trades",
      tradesApi: "/business/my-trade-pairs",
    };
  }
  if (role === "MANAGER") {
    return {
      role,
      ordersPage: "/team?view=orders",
      ordersApi: "/team/:staffId/orders",
      tradesPage: "/team?view=trades",
      tradesApi: "/team/:staffId/trades",
    };
  }
  return { role, ordersPage: null, ordersApi: null, tradesPage: null, tradesApi: null };
}
