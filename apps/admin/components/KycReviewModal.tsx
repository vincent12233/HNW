"use client";

import {
  CheckOutlined,
  CloseOutlined,
  ReloadOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Descriptions,
  Image,
  Input,
  Space,
  Spin,
  Typography,
} from "antd";
import { useEffect, useId, useState } from "react";

import OpsModal from "@/components/OpsModal";
import OpsStatusTag from "@/components/OpsStatusTag";
import {
  KYC_REVIEW_COPY,
  canSubmitKycReview,
  kycConfirmSummary,
  kycStatusPresentation,
  previewDataUrl,
  reviewNoteError,
  type KycDecision,
  type KycFilePreview,
  type KycSubmissionView,
} from "@/lib/kyc-review";
import { maskOpsPhone } from "@/lib/ops-directory";
import { formatOpsDateTime } from "@/lib/ops-format";
import { vipTierLabel } from "@/lib/vip";

const { Text } = Typography;

type ReviewFiles = {
  front: KycFilePreview | null;
  back: KycFilePreview | null;
  selfie: KycFilePreview | null;
  signature: KycFilePreview | null;
};

type Props = {
  open: boolean;
  submission: KycSubmissionView | null;
  files: ReviewFiles;
  fileLoading: boolean;
  previewError: string;
  note: string;
  onNoteChange: (value: string) => void;
  saving: boolean;
  onClose: () => void;
  onRetryPreview: () => void;
  onSubmit: (decision: KycDecision) => void;
};

function PreviewPane({
  title,
  file,
  fallback,
  loading,
}: {
  title: string;
  file: KycFilePreview | null;
  fallback: string;
  loading?: boolean;
}) {
  const src = previewDataUrl(file);
  if (loading && !file) {
    return (
      <section className="kyc-preview-card" aria-label={title}>
        <h4>{title}</h4>
        <div className="kyc-preview-frame kyc-preview-skeleton" aria-busy="true">
          <Text type="secondary">{KYC_REVIEW_COPY.previewLoading}</Text>
        </div>
      </section>
    );
  }
  if (!file) {
    return (
      <section className="kyc-preview-card" aria-label={title}>
        <h4>{title}</h4>
        <div className="kyc-preview-frame">
          <Text type="secondary">{fallback}</Text>
        </div>
      </section>
    );
  }
  return (
    <section className="kyc-preview-card" aria-label={title}>
      <h4>{title}</h4>
      <Space orientation="vertical" size="small" style={{ width: "100%" }}>
        {file.mimeType.startsWith("image/") ? (
          <div className="kyc-preview-frame">
            <Image src={src} alt={title} style={{ maxHeight: 360, width: "auto", objectFit: "contain" }} />
          </div>
        ) : file.mimeType === "application/pdf" ? (
          <iframe title={title} src={src} className="kyc-preview-frame kyc-preview-frame--pdf" />
        ) : (
          <Alert type="info" showIcon title="该文件类型无法预览。" />
        )}
      </Space>
    </section>
  );
}

export default function KycReviewModal({
  open,
  submission,
  files,
  fileLoading,
  previewError,
  note,
  onNoteChange,
  saving,
  onClose,
  onRetryPreview,
  onSubmit,
}: Props) {
  const noteId = useId();
  const [pendingDecision, setPendingDecision] = useState<KycDecision | null>(null);
  const [noteIssue, setNoteIssue] = useState<string | null>(null);
  const reviewing = submission?.status === "PENDING";
  const statusView = submission
    ? kycStatusPresentation(submission.status, submission.reviewNote)
    : null;
  const canApprove = canSubmitKycReview({
    status: submission?.status || "",
    hasFrontFile: Boolean(files.front),
    fileLoading,
    saving,
    decision: "APPROVED",
    note,
  });
  const canReject = canSubmitKycReview({
    status: submission?.status || "",
    hasFrontFile: Boolean(files.front),
    fileLoading,
    saving,
    decision: "REJECTED",
    note,
  });
  const forbiddenPreview = previewError === KYC_REVIEW_COPY.previewForbidden;

  useEffect(() => {
    if (!open) {
      setPendingDecision(null);
      setNoteIssue(null);
    }
  }, [open]);

  function requestDecision(decision: KycDecision) {
    const issue = reviewNoteError(decision, note);
    setNoteIssue(issue);
    if (issue) return;
    if (
      !canSubmitKycReview({
        status: submission?.status || "",
        hasFrontFile: Boolean(files.front),
        fileLoading,
        saving,
        decision,
        note,
      })
    ) {
      return;
    }
    setPendingDecision(decision);
  }

  return (
    <>
      <OpsModal
        className="kyc-review-modal"
        rootClassName="kyc-review-modal-root"
        title={reviewing ? "审核 KYC 提交" : "查看 KYC 提交"}
        open={open}
        width="min(920px, calc(100vw - 16px))"
        onCancel={() => {
          if (saving) return;
          onClose();
        }}
        destroyOnHidden
        maskClosable={!saving}
        keyboard={!saving}
        closable={!saving}
        footer={
          reviewing
            ? [
                <Button
                  key="reject"
                  danger
                  icon={<CloseOutlined aria-hidden />}
                  disabled={!canReject || saving}
                  aria-label="拒绝该 KYC 提交"
                  onClick={() => requestDecision("REJECTED")}
                >
                  拒绝
                </Button>,
                <Button
                  key="approve"
                  type="primary"
                  icon={<CheckOutlined aria-hidden />}
                  disabled={!canApprove || saving}
                  loading={saving && pendingDecision === "APPROVED"}
                  aria-label="通过该 KYC 提交"
                  onClick={() => requestDecision("APPROVED")}
                >
                  通过
                </Button>,
              ]
            : [
                <Button key="close" onClick={onClose}>
                  关闭
                </Button>,
              ]
        }
      >
        {submission ? (
          <Space orientation="vertical" size="middle" style={{ width: "100%" }} className="kyc-review-body">
            <section className="kyc-step" aria-labelledby="kyc-step-profile">
              <h3 id="kyc-step-profile">{KYC_REVIEW_COPY.stepProfile}</h3>
              <Descriptions size="small" column={1} bordered>
                <Descriptions.Item label="客户名称">
                  <span className="kyc-wrap-text">{submission.fullName || "未命名客户"}</span>
                </Descriptions.Item>
                <Descriptions.Item label="客户标识">
                  <span className="ops-id">{submission.userId}</span>
                </Descriptions.Item>
                <Descriptions.Item label="脱敏手机号">{maskOpsPhone(submission.phone)}</Descriptions.Item>
                <Descriptions.Item label="证件类型">{submission.documentType || "—"}</Descriptions.Item>
                <Descriptions.Item label={KYC_REVIEW_COPY.filenameHint}>
                  {submission.recognizedType || "—"}
                </Descriptions.Item>
                {submission.ownerStaffName ? (
                  <Descriptions.Item label="所属业务员">{submission.ownerStaffName}</Descriptions.Item>
                ) : null}
                {submission.clientTier ? (
                  <Descriptions.Item label="VIP">
                    <span aria-label={`VIP ${vipTierLabel(submission.clientTier)}`}>
                      {vipTierLabel(submission.clientTier)}
                    </span>
                  </Descriptions.Item>
                ) : null}
              </Descriptions>
            </section>

            {previewError ? (
              <Alert
                type="error"
                showIcon
                role="alert"
                className="kyc-alert"
                title={previewError}
                action={
                  <Button
                    size="small"
                    icon={<ReloadOutlined aria-hidden />}
                    aria-label="重新加载证件预览"
                    onClick={onRetryPreview}
                    disabled={fileLoading || saving}
                  >
                    重试预览
                  </Button>
                }
              />
            ) : null}

            <section className="kyc-step" aria-labelledby="kyc-step-docs">
              <h3 id="kyc-step-docs">{KYC_REVIEW_COPY.stepDocuments}</h3>
              <Spin spinning={fileLoading} tip={KYC_REVIEW_COPY.previewLoading}>
                <div className="kyc-preview-grid" aria-busy={fileLoading}>
                  <PreviewPane
                    title="证件正面"
                    file={files.front}
                    loading={fileLoading}
                    fallback={
                      forbiddenPreview
                        ? KYC_REVIEW_COPY.previewForbidden
                        : fileLoading
                          ? KYC_REVIEW_COPY.previewLoading
                          : "证件正面不可用"
                    }
                  />
                  <PreviewPane
                    title="证件反面"
                    file={files.back}
                    loading={fileLoading}
                    fallback={
                      submission.backFileName
                        ? "证件反面暂时无法加载"
                        : "该申请未提交证件反面"
                    }
                  />
                </div>
              </Spin>
            </section>

            <section className="kyc-step" aria-labelledby="kyc-step-selfie">
              <h3 id="kyc-step-selfie">{KYC_REVIEW_COPY.stepSelfie}</h3>
              <PreviewPane
                title="自拍"
                file={files.selfie}
                loading={fileLoading}
                fallback={submission.hasSelfie ? "自拍暂时无法加载" : "该申请未提交自拍"}
              />
            </section>

            <section className="kyc-step" aria-labelledby="kyc-step-sign">
              <h3 id="kyc-step-sign">{KYC_REVIEW_COPY.stepSignature}</h3>
              <PreviewPane
                title="手写签名"
                file={files.signature}
                loading={fileLoading}
                fallback={
                  submission.hasSignature ? "签名暂时无法加载" : "该申请未提交签名"
                }
              />
            </section>

            <section className="kyc-step" aria-labelledby="kyc-step-bank">
              <h3 id="kyc-step-bank">{KYC_REVIEW_COPY.stepBank}</h3>
              {submission.bankDetails ? (
                <Descriptions size="small" column={1} bordered>
                  <Descriptions.Item label="银行">{submission.bankDetails.bankName || "—"}</Descriptions.Item>
                  <Descriptions.Item label="开户名">
                    <span className="kyc-wrap-text">{submission.bankDetails.accountHolder || "—"}</span>
                  </Descriptions.Item>
                  <Descriptions.Item label="账号">{submission.bankDetails.accountNumber || "—"}</Descriptions.Item>
                  <Descriptions.Item label="IFSC">{submission.bankDetails.ifscCode || "未提供"}</Descriptions.Item>
                </Descriptions>
              ) : (
                <Alert type="info" showIcon title="该提交未包含银行资料。" />
              )}
              <Text type="secondary">以上资料来自客户提交，需人工核对。系统未做影像识别、活体或银行自动验证，也不提供一次性校验码。</Text>
            </section>

            <section className="kyc-step" aria-labelledby="kyc-step-review">
              <h3 id="kyc-step-review">{KYC_REVIEW_COPY.stepReview}</h3>
              <Descriptions size="small" column={1} bordered>
                <Descriptions.Item label="KYC 状态">
                  {statusView ? (
                    <OpsStatusTag
                      code={statusView.status === "UNKNOWN" ? submission.status : statusView.status}
                      label={statusView.label}
                    />
                  ) : null}
                </Descriptions.Item>
                <Descriptions.Item label="提交时间">{formatOpsDateTime(submission.createdAt)}</Descriptions.Item>
                {submission.reviewedByName || submission.reviewedAt ? (
                  <>
                    <Descriptions.Item label="审核人">{submission.reviewedByName || "—"}</Descriptions.Item>
                    <Descriptions.Item label="审核时间">{formatOpsDateTime(submission.reviewedAt)}</Descriptions.Item>
                  </>
                ) : (
                  <Descriptions.Item label="审核记录">{KYC_REVIEW_COPY.noReviewerOnList}</Descriptions.Item>
                )}
                {statusView?.resubmitHint ? (
                  <Descriptions.Item label="补件说明">
                    <span className="kyc-wrap-text">{statusView.resubmitHint}</span>
                  </Descriptions.Item>
                ) : null}
              </Descriptions>
            </section>

            <div>
              <label htmlFor={noteId}>
                <Text strong>审核备注</Text>
              </label>
              <Input.TextArea
                id={noteId}
                rows={4}
                maxLength={1000}
                showCount
                disabled={saving || !reviewing}
                placeholder={reviewing ? "拒绝时必填，将作为客户补件说明" : "审核备注"}
                value={note}
                onChange={(event) => {
                  onNoteChange(event.target.value);
                  if (noteIssue) setNoteIssue(reviewNoteError("REJECTED", event.target.value));
                }}
              />
              {noteIssue ? (
                <Text type="danger" role="alert" className="kyc-note-error">
                  {noteIssue}
                </Text>
              ) : (
                <Text type="secondary" className="kyc-note-hint">
                  通过可不填备注。拒绝必须填写备注，备注只解释已拒绝状态。
                </Text>
              )}
            </div>
          </Space>
        ) : null}
      </OpsModal>

      <OpsModal
        className="kyc-confirm-modal"
        rootClassName="kyc-confirm-modal-root"
        title={pendingDecision === "APPROVED" ? "确认通过" : "确认拒绝"}
        open={!!pendingDecision}
        zIndex={2100}
        okText="提交到服务器"
        cancelText="返回"
        confirmLoading={saving}
        okButtonProps={{ danger: pendingDecision === "REJECTED", disabled: saving }}
        onOk={() => {
          if (!pendingDecision || saving) return;
          onSubmit(pendingDecision);
        }}
        onCancel={() => {
          if (!saving) setPendingDecision(null);
        }}
      >
        {submission && pendingDecision ? (
          <Space orientation="vertical" size="small">
            <p>{kycConfirmSummary(submission, pendingDecision)}</p>
            <p>
              {pendingDecision === "APPROVED"
                ? KYC_REVIEW_COPY.confirmApprove
                : KYC_REVIEW_COPY.confirmReject}
            </p>
          </Space>
        ) : null}
      </OpsModal>
    </>
  );
}
