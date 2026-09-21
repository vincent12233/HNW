"use client";

import { useEffect, useState } from "react";

/** Display-only phone mask. Matches existing VIP staff masking. */
export function maskOpsPhone(phone?: string | null, empty = "—") {
  if (!phone) return empty;
  const digits = phone.replace(/\D/g, "");
  if (digits.length < 4) return "****";
  return `******${digits.slice(-4)}`;
}

export function filterLoadedRows<T>(
  rows: T[],
  keyword: string,
  valuesOf: (row: T) => Array<string | number | null | undefined>,
) {
  const needle = keyword.trim().toLowerCase();
  if (!needle) return rows;
  return rows.filter((row) =>
    valuesOf(row).some((value) =>
      String(value ?? "")
        .toLowerCase()
        .includes(needle),
    ),
  );
}

export function useDebouncedValue<T>(value: T, delayMs = 300) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timer);
  }, [value, delayMs]);
  return debounced;
}

export function maskBankAccount(value?: string | null, empty = "—") {
  if (!value) return empty;
  const compact = value.replace(/\s/g, "");
  if (compact.length < 4) return "••••";
  return `••••${compact.slice(-4)}`;
}

export function maskIfsc(value?: string | null, empty = "—") {
  if (!value) return empty;
  if (value.length < 4) return "••••";
  return `${value.slice(0, 4)}••••`;
}

export function maskUpi(value?: string | null, empty = "—") {
  if (!value) return empty;
  const [name, provider] = value.split("@");
  const maskedName = !name || name.length <= 2 ? "••" : `••${name.slice(-2)}`;
  return provider ? `${maskedName}@${provider}` : maskedName;
}

export function maskedPayoutLabel(record: {
  upiId?: string | null;
  bankName?: string | null;
  accountNumber?: string | null;
  ifscCode?: string | null;
}) {
  if (record.upiId) return `UPI：${maskUpi(record.upiId)}`;
  const parts = [record.bankName, maskBankAccount(record.accountNumber, ""), maskIfsc(record.ifscCode, "")].filter(
    (part) => part && part !== "—",
  );
  return parts.length ? parts.join(" / ") : "—";
}

export const LOADED_FILTER_CAPTION =
  "以下筛选只作用于已经加载的结果，不是新的服务端查询。";

export const DIRECTORY_SCOPE_COPY = {
  adminCustomers:
    "超级管理员与财务查看全局客户。KYC 状态只在详情接口返回时展示。VIP 仅作为资料字段，本页不能修改。",
  financeCustomers:
    "财务查看客户账户摘要。本页不提供客户、团队或 VIP 写入。",
  businessCustomers:
    "业务员只能查看自己名下客户。不能查看同团队其他业务员客户，也不能修改归属。VIP 调整请使用业务员 VIP 页。",
  supportCustomers:
    "专用运营员沿用现有客户范围。本页不新增客户或团队写权限。",
  businessUsers:
    "员工列表来自现有业务员接口。未返回所属管理员时不展示该列。",
  managerTeam:
    "管理员只能看到自己名下业务员及这些业务员的客户。跨团队 ID 由服务端返回 403/404。",
  adminTeam:
    "超级管理员查看管理员团队。跨团队归属仍使用团队归属管理页，本页不重做转移。",
  noKycOnList: "列表接口未返回 KYC 状态，不在前端伪装该列。",
  noCreatedAt: "当前接口未返回创建时间，不在前端推算。",
};

export function accountStatusLabel(status?: string | null) {
  if (status === "ACTIVE") return "正常";
  if (status === "SUSPENDED") return "已暂停";
  if (status === "DISABLED" || status === "INACTIVE") return "已停用";
  return status || "—";
}
