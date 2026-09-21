/** Display helpers for IPO, OTC, instrument, and fund catalog consoles. */

export const IPO_CATALOG_STATUSES = [
  "DRAFT",
  "PUBLISHED",
  "OPEN",
  "CLOSED",
  "LISTED",
  "ALLOTMENT_DONE",
] as const;

export const OTC_STATUSES = ["PENDING", "APPROVED", "REJECTED"] as const;

export function ipoCatalogStatusLabel(status?: string | null) {
  if (status === "PUBLISHED") return "已上架（APP 可认购）";
  if (status === "OPEN") return "已上架（旧数据）";
  if (status === "CLOSED") return "已下架";
  if (status === "LISTED") return "已上市（展示行情，仍按申购价结算）";
  if (status === "ALLOTMENT_DONE") return "分配已完成";
  if (status === "DRAFT") return "草稿";
  return undefined;
}

export function ipoApplicationStatusLabel(status?: string | null, draftQuantity?: number | null) {
  if (status === "PENDING") return Number(draftQuantity) > 0 ? "待公布分配" : "待分配";
  if (status === "ALLOTTED") return "已公布分配";
  if (status === "APPROVED") return "已通过";
  if (status === "REJECTED") return "已拒绝";
  return undefined;
}

export const PRODUCT_COPY = {
  ipoTitle: "IPO 上架管理",
  ipoAppsTitle: "IPO 分配",
  ipoDebtsTitle: "IPO 欠款",
  otcTitle: "OTC 订单审核",
  instrumentsTitle: "股票资料库",
  fundsTitle: "基金后台",
  catalogNotTraded: "目录记录不是已交易、已批准或已结算。状态使用现有接口返回值。",
  listedNotSettled: "上市只表示展示行情；结算仍按申购价，不把目录当成已成交。",
  noVip: "VIP 不作为产品优先级或交易入口。",
  loadedFilter: "以下搜索只作用于已经加载的结果，不是新的服务端查询。",
};

export function productWorkflowForRole(role: string) {
  if (role === "ADMIN") {
    return {
      role,
      instrumentsPage: "/instruments",
      ipoPage: "/ipo-management",
      fundsPage: "/funds",
      otcPage: null,
      ipoAppsPage: null,
      canApproveOtc: false,
      canAllocateIpo: false,
    };
  }
  if (role === "BUSINESS" || role === "SUPPORT") {
    return {
      role,
      instrumentsPage: null,
      ipoPage: null,
      fundsPage: null,
      otcPage: "/business-otc",
      ipoAppsPage: "/business-ipo",
      canApproveOtc: true,
      canAllocateIpo: true,
    };
  }
  if (role === "FINANCE") {
    return {
      role,
      instrumentsPage: null,
      ipoPage: null,
      fundsPage: null,
      otcPage: null,
      ipoAppsPage: null,
      ipoDebtsPage: "/ipo-debts",
      canApproveOtc: false,
      canAllocateIpo: false,
    };
  }
  return {
    role,
    instrumentsPage: null,
    ipoPage: null,
    fundsPage: null,
    otcPage: null,
    ipoAppsPage: null,
    canApproveOtc: false,
    canAllocateIpo: false,
  };
}
