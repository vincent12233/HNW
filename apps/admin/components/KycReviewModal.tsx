"use client";

import {
  CheckOutlined,
  CloseOutlined,
  DownloadOutlined,
  ReloadOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Image,
  Input,
  Modal,
  Space,
  Spin,
  Typography,
} from "antd";
import { useEffect, useId, useState } from "react";

import {
  KYC_REVIEW_COPY,
  canSubmitKycReview,
  previewDataUrl,
  reviewNoteError,
  type KycDecision,
  type KycFilePreview,
  type KycSubmissionView,
} from "@/lib/kyc-review";

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
}: {
  title: string;
  file: KycFilePreview | null;
  fallback: string;
}) {
  const src = previewDataUrl(file);
  if (!file) {
    return (
      <Card size="small" title={title} className="kyc-preview-card">
        <Text type="secondary">{fallback}</Text>
      </Card>
    );
  }
  return (
    <Card size="small" title={title} className="kyc-preview-card">
      <Space orientation="vertical" size="small" style={{ width: "100%" }}>
        {file.mimeType.startsWith("image/") ? (
          <div className="kyc-preview-frame">
            <Image src={src} alt={title} style={{ maxHeight: 360, objectFit: "contain" }} />
          </div>
        ) : file.mimeType === "application/pdf" ? (
          <iframe title={title} src={src} className="kyc-preview-frame kyc-preview-frame--pdf" />
        ) : (
          <Alert type="info" showIcon title="该文件类型无法预览，请下载后查看。" />
        )}
        <Button
          icon={<DownloadOutlined aria-hidden />}
          href={src}
          download={file.fileName || title}
          aria-label={`下载${title}`}
        >
          下载
        </Button>
      </Space>
    </Card>
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
      <Modal
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
        mask={{ closable: !saving }}
        keyboard={!saving}
        closable={!saving}
        footer={
          reviewing
            ? [
                <Button
                  key="reject"
                  danger
                  icon={<CloseOutlined aria-hidden />}
                  disabled={!canReject}
                  aria-label="拒绝该 KYC 提交"
                  onClick={() => requestDecision("REJECTED")}
                >
                  拒绝
                </Button>,
                <Button
                  key="approve"
                  type="primary"
                  icon={<CheckOutlined aria-hidden />}
                  disabled={!canApprove}
                  loading={saving}
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
            <div className="kyc-meta-grid">
              <div>
                <Text type="secondary">客户</Text>
                <div>
                  <Text strong>{submission.fullName || "未命名客户"}</Text>
                </div>
              </div>
              <div>
                <Text type="secondary">手机号</Text>
                <div>
                  {submission.phone?.startsWith("+")
                    ? submission.phone
                    : submission.phone
                      ? `+91 ${submission.phone}`
                      : "-"}
                </div>
              </div>
              <div>
                <Text type="secondary">证件类型</Text>
                <div>{submission.documentType || "-"}</div>
              </div>
              <div>
                <Text type="secondary">{KYC_REVIEW_COPY.filenameHint}</Text>
                <div>{submission.recognizedType || "-"}</div>
              </div>
              {submission.ownerStaffName ? (
                <div>
                  <Text type="secondary">所属业务员</Text>
                  <div>{submission.ownerStaffName}</div>
                </div>
              ) : null}
            </div>

            {submission.bankDetails ? (
              <Card size="small" title="银行资料" className="kyc-bank-card">
                <div className="kyc-meta-grid">
                  <div>银行：{submission.bankDetails.bankName || "-"}</div>
                  <div>开户名：{submission.bankDetails.accountHolder || "-"}</div>
                  <div>账号：{submission.bankDetails.accountNumber || "-"}</div>
                  <div>IFSC：{submission.bankDetails.ifscCode || "未提供"}</div>
                </div>
                <Text type="secondary">以上资料来自客户提交，需人工核对，系统未做银行自动验证。</Text>
              </Card>
            ) : (
              <Alert type="info" showIcon title="该提交未包含银行资料。" />
            )}

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

            <Spin spinning={fileLoading} tip="正在加载鉴权预览">
              <div className="kyc-preview-grid" aria-busy={fileLoading}>
                <PreviewPane
                  title="证件正面"
                  file={files.front}
                  fallback={fileLoading ? "正在加载正面" : "证件正面不可用"}
                />
                <PreviewPane
                  title="证件反面"
                  file={files.back}
                  fallback={
                    submission.backFileName
                      ? "证件反面暂时无法加载"
                      : "该申请未提交证件反面"
                  }
                />
                <PreviewPane
                  title="自拍"
                  file={files.selfie}
                  fallback={
                    submission.hasSelfie ? "自拍暂时无法加载" : "该申请未提交自拍"
                  }
                />
                <PreviewPane
                  title="手写签名"
                  file={files.signature}
                  fallback={
                    submission.hasSignature
                      ? "签名暂时无法加载"
                      : "该申请未提交签名"
                  }
                />
              </div>
            </Spin>

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
      </Modal>

      <Modal
        className="kyc-confirm-modal"
        rootClassName="kyc-confirm-modal-root"
        title={pendingDecision === "APPROVED" ? "确认通过" : "确认拒绝"}
        open={!!pendingDecision}
        okText="提交到服务器"
        cancelText="返回"
        confirmLoading={saving}
        okButtonProps={{ danger: pendingDecision === "REJECTED" }}
        onOk={() => {
          if (!pendingDecision) return;
          onSubmit(pendingDecision);
          setPendingDecision(null);
        }}
        onCancel={() => {
          if (!saving) setPendingDecision(null);
        }}
      >
        <p>
          {pendingDecision === "APPROVED"
            ? KYC_REVIEW_COPY.confirmApprove
            : KYC_REVIEW_COPY.confirmReject}
        </p>
      </Modal>
    </>
  );
}
