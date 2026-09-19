export const KYC_STATUSES = ["PENDING", "APPROVED", "REJECTED"] as const;
export const KYC_DECISIONS = ["APPROVED", "REJECTED"] as const;

export type KycStatus = (typeof KYC_STATUSES)[number];
export type KycDecision = (typeof KYC_DECISIONS)[number];
export type KycStatusFilter = "ALL" | KycStatus;

export type KycBankDetails = {
  accountHolder: string;
  bankName: string;
  accountNumber: string;
  ifscCode: string;
};

export type KycFilePreview = {
  fileName: string;
  mimeType: string;
  contentBase64: string;
};

export type KycSubmissionView = {
  id: string;
  documentType: string;
  status: string;
  fileName: string;
  backFileName?: string | null;
  hasSelfie?: boolean;
  hasSignature?: boolean;
  recognizedType?: string | null;
  reviewNote?: string | null;
  createdAt: string;
  userId: string;
  fullName: string;
  phone?: string | null;
  bankDetails?: KycBankDetails | null;
  ownerStaffId?: string;
  ownerStaffName?: string;
};

export const KYC_REVIEW_COPY = {
  title: "KYC 审核",
  eyebrow: "MANUAL REVIEW",
  description:
    "客户完成证件、自拍、签名和银行资料六步提交后，由审核员人工核对。状态只有待审核、已通过、已拒绝。拒绝并填写备注时，备注只作为补件说明，不是新的审核状态。结果只在服务器确认成功后刷新列表。系统不提供 OTP、OCR、活体检测或银行自动验证。",
  empty: "当前没有 KYC 提交。客户完成六步文件提交后会出现在此列表。",
  filteredEmpty: "当前筛选下没有 KYC 提交。",
  loading: "正在加载 KYC 列表",
  listError: "KYC 列表加载失败，请重试。",
  previewError: "审核资料加载失败，请重试。",
  filenameHint: "文件名提示",
  rejectNoteRequired: "拒绝时请填写审核备注，客户将把它作为补件说明。",
  confirmApprove: "确认将该提交标记为已通过？结果只在服务器成功后生效，此时不会提前显示审核成功。",
  confirmReject: "确认将该提交标记为已拒绝？结果只在服务器成功后生效。填写的备注将作为补件说明，不会新增审核状态。",
  approveSuccess: "KYC 已通过",
  rejectSuccess: "KYC 已拒绝",
  reviewFailure: "KYC 审核失败，请刷新确认最新状态后重试",
  resubmitHint: "需补件：客户需按审核备注补交后重新提交",
  rejectedWithoutNote: "已拒绝",
  pendingLabel: "待审核",
  approvedLabel: "已通过",
  rejectedLabel: "已拒绝",
  viewAction: "查看",
  reviewAction: "审核",
} as const;

const FORBIDDEN_CLAIM =
  /OCR 已|已完成 OCR|活体通过|活体检测已|OTP 校验|OTP 验证|银行已验证|自动验证通过|已自动通过|人脸识别通过|需补件状态/;

export function isKycStatus(value: string): value is KycStatus {
  return KYC_STATUSES.includes(value as KycStatus);
}

export function isKycDecision(value: string): value is KycDecision {
  return KYC_DECISIONS.includes(value as KycDecision);
}

export function kycStatusPresentation(
  status: string,
  reviewNote?: string | null,
): {
  status: KycStatus | "UNKNOWN";
  label: string;
  color: "orange" | "green" | "red" | "default";
  resubmitHint: string | null;
} {
  if (status === "PENDING") {
    return { status, label: KYC_REVIEW_COPY.pendingLabel, color: "orange", resubmitHint: null };
  }
  if (status === "APPROVED") {
    return { status, label: KYC_REVIEW_COPY.approvedLabel, color: "green", resubmitHint: null };
  }
  if (status === "REJECTED") {
    return {
      status,
      label: KYC_REVIEW_COPY.rejectedLabel,
      color: "red",
      resubmitHint: reviewNote?.trim() ? KYC_REVIEW_COPY.resubmitHint : null,
    };
  }
  return { status: "UNKNOWN", label: status || "-", color: "default", resubmitHint: null };
}

export function canReviewKyc(status: string): boolean {
  return status === "PENDING";
}

export function reviewNoteError(decision: KycDecision, note: string): string | null {
  if (decision !== "REJECTED") return null;
  return note.trim().length >= 2 ? null : KYC_REVIEW_COPY.rejectNoteRequired;
}

export function canSubmitKycReview(input: {
  status: string;
  hasFrontFile: boolean;
  fileLoading: boolean;
  saving: boolean;
  decision: KycDecision;
  note: string;
}): boolean {
  if (!canReviewKyc(input.status)) return false;
  if (!input.hasFrontFile || input.fileLoading || input.saving) return false;
  return reviewNoteError(input.decision, input.note) == null;
}

export function acquireReviewLock(lock: { current: boolean }): boolean {
  if (lock.current) return false;
  lock.current = true;
  return true;
}

export function releaseReviewLock(lock: { current: boolean }): void {
  lock.current = false;
}

export function buildKycReviewBody(
  submissionId: string,
  decision: KycDecision,
  note: string,
): { submissionId: string; decision: KycDecision; note?: string } {
  const trimmed = note.trim();
  return trimmed
    ? { submissionId, decision, note: trimmed.slice(0, 1000) }
    : { submissionId, decision };
}

export function parseKycSubmission(row: unknown): KycSubmissionView {
  if (!row || typeof row !== "object") {
    throw new Error("Invalid KYC submission");
  }
  const item = row as Partial<KycSubmissionView>;
  if (typeof item.id !== "string" || !item.id) {
    throw new Error("Invalid KYC submission");
  }
  return item as KycSubmissionView;
}

export function parseKycList(data: unknown): KycSubmissionView[] {
  if (!Array.isArray(data)) {
    throw new Error("Invalid KYC list");
  }
  return data.map(parseKycSubmission);
}

export function filterKycList(
  items: KycSubmissionView[],
  filter: KycStatusFilter,
): KycSubmissionView[] {
  if (filter === "ALL") return items;
  return items.filter((item) => item.status === filter);
}

export function countKycByStatus(items: KycSubmissionView[]): Record<KycStatusFilter, number> {
  return {
    ALL: items.length,
    PENDING: items.filter((item) => item.status === "PENDING").length,
    APPROVED: items.filter((item) => item.status === "APPROVED").length,
    REJECTED: items.filter((item) => item.status === "REJECTED").length,
  };
}

export function partialPreviewMessage(missing: string[]): string {
  return `部分资料暂时无法加载：${missing.join("、")}。证件正面仍可人工审核。`;
}

export function formatKycDate(value?: string | null): string {
  return value ? new Date(value).toLocaleString("zh-CN") : "-";
}

export function previewDataUrl(file: KycFilePreview | null): string {
  if (!file) return "";
  return `data:${file.mimeType};base64,${file.contentBase64}`;
}

export function containsForbiddenKycClaim(text: string): boolean {
  return FORBIDDEN_CLAIM.test(text);
}

export type KycRoleWorkflow = {
  role: string;
  page: string | null;
  listApi: string | null;
  reviewApi: string | null;
  fileApi: string | null;
};

/** Existing role isolation. Do not expand MANAGER onto /kyc/business/*. */
export function kycWorkflowForRole(role: string): KycRoleWorkflow {
  if (role === "BUSINESS" || role === "SUPPORT") {
    return {
      role,
      page: "/business-kyc",
      listApi: "/kyc/business/pending",
      reviewApi: "/kyc/business/review",
      fileApi: "/kyc/business/:id/file?side=",
    };
  }
  if (role === "MANAGER") {
    return {
      role,
      page: "/team?view=kyc",
      listApi: "/team/:staffId/kyc",
      reviewApi: "/team/:staffId/kyc",
      fileApi: "/team/:staffId/kyc/:id/file?side=",
    };
  }
  return { role, page: null, listApi: null, reviewApi: null, fileApi: null };
}

export function collectPreviewGaps(input: {
  backRequested: boolean;
  backFailed: boolean;
  selfieRequested: boolean;
  selfieFailed: boolean;
  signatureRequested: boolean;
  signatureFailed: boolean;
}): string[] {
  return [
    input.backRequested && input.backFailed ? "证件反面" : "",
    input.selfieRequested && input.selfieFailed ? "自拍" : "",
    input.signatureRequested && input.signatureFailed ? "签名" : "",
  ].filter(Boolean);
}
