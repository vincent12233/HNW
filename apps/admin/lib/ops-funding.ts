/** Display helpers for funding consoles. No ledger or approval semantics. */

export const FUNDING_COPY = {
  depositsTitle: "上分订单",
  withdrawalsTitle: "提现审核",
  loansTitle: "贷款管理",
  businessDepositsTitle: "客户入金记录",
  businessWithdrawalsTitle: "客户提现记录",
  noGateway: "本页不接入支付网关，也不模拟到账。入账只在财务或专用运营员确认后发生。",
  noVipPriority: "VIP 不作为入金、提现或贷款的优先级或限额。",
  noDualApproval: "当前为单人审批，不新增双人复核。",
  withdrawMask: "收款账号按脱敏展示，完整账号仍只保存在服务端。",
  loadedFilter: "以下搜索只作用于已经加载的结果，不是新的服务端查询。",
};

export function fundingWorkflowForRole(role: string) {
  if (role === "FINANCE") {
    return {
      role,
      depositsPage: "/deposits",
      withdrawalsPage: "/withdrawals",
      loansPage: "/loans",
      canApproveWithdrawal: true,
      canCredit: true,
    };
  }
  if (role === "SUPPORT") {
    return {
      role,
      depositsPage: "/deposits",
      withdrawalsPage: "/business-withdrawals",
      loansPage: null,
      canApproveWithdrawal: false,
      canCredit: true,
    };
  }
  if (role === "BUSINESS") {
    return {
      role,
      depositsPage: "/business-deposits",
      withdrawalsPage: "/business-withdrawals",
      loansPage: "/loans",
      canApproveWithdrawal: false,
      canCredit: false,
    };
  }
  if (role === "ADMIN") {
    return {
      role,
      depositsPage: null,
      withdrawalsPage: null,
      loansPage: null,
      canApproveWithdrawal: false,
      canCredit: false,
    };
  }
  return {
    role,
    depositsPage: null,
    withdrawalsPage: null,
    loansPage: null,
    canApproveWithdrawal: false,
    canCredit: false,
  };
}
