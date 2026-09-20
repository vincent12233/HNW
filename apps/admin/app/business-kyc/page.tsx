"use client";

import { useEffect, useRef, useState } from "react";
import { Space, message } from "antd";

import AdminShell from "@/components/AdminShell";
import KycReviewList from "@/components/KycReviewList";
import KycReviewModal from "@/components/KycReviewModal";
import OpsPageHeader from "@/components/OpsPageHeader";
import { api, getApiErrorMessage } from "@/lib/api";
import {
  KYC_REVIEW_COPY,
  acquireReviewLock,
  buildKycReviewBody,
  canSubmitKycReview,
  collectPreviewGaps,
  describeKycPreviewFailure,
  parseKycList,
  partialPreviewMessage,
  releaseReviewLock,
  type KycDecision,
  type KycFilePreview,
  type KycSubmissionView,
} from "@/lib/kyc-review";

const EMPTY_FILES = {
  front: null,
  back: null,
  selfie: null,
  signature: null,
} as { front: KycFilePreview | null; back: KycFilePreview | null; selfie: KycFilePreview | null; signature: KycFilePreview | null };

export default function BusinessKycPage() {
  const [items, setItems] = useState<KycSubmissionView[]>([]);
  const [loading, setLoading] = useState(false);
  const [listError, setListError] = useState("");
  const [fileLoading, setFileLoading] = useState(false);
  const [previewError, setPreviewError] = useState("");
  const [reviewing, setReviewing] = useState<KycSubmissionView | null>(null);
  const [files, setFiles] = useState(EMPTY_FILES);
  const [note, setNote] = useState("");
  const [reviewSaving, setReviewSaving] = useState(false);
  const previewGeneration = useRef(0);
  const reviewLock = useRef(false);

  async function loadItems() {
    setLoading(true);
    setListError("");
    try {
      const response = await api.get("/kyc/business/pending");
      setItems(parseKycList(response.data));
    } catch (requestError: unknown) {
      setItems([]);
      setListError(getApiErrorMessage(requestError, "") || KYC_REVIEW_COPY.listError);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadItems();
  }, []);

  async function loadFile(record: KycSubmissionView) {
    const generation = ++previewGeneration.current;
    setFileLoading(true);
    setPreviewError("");
    setFiles(EMPTY_FILES);
    try {
      const fetchSide = async (side: string) =>
        (await api.get<KycFilePreview>(`/kyc/business/${record.id}/file?side=${side}`)).data;
      const results = await Promise.allSettled([
        fetchSide("front"),
        record.backFileName ? fetchSide("back") : Promise.resolve(null),
        record.hasSelfie ? fetchSide("selfie") : Promise.resolve(null),
        record.hasSignature ? fetchSide("signature") : Promise.resolve(null),
      ]);
      const [frontResult, backResult, selfieResult, signatureResult] = results;
      const front = frontResult.status === "fulfilled" ? frontResult.value : null;
      if (!front) {
        throw frontResult.status === "rejected"
          ? frontResult.reason
          : new Error("Front document is unavailable");
      }
      if (generation !== previewGeneration.current) return;
      setFiles({
        front,
        back: backResult.status === "fulfilled" ? backResult.value : null,
        selfie: selfieResult.status === "fulfilled" ? selfieResult.value : null,
        signature: signatureResult.status === "fulfilled" ? signatureResult.value : null,
      });
      const missing = collectPreviewGaps({
        backRequested: Boolean(record.backFileName),
        backFailed: backResult.status === "rejected",
        selfieRequested: Boolean(record.hasSelfie),
        selfieFailed: selfieResult.status === "rejected",
        signatureRequested: Boolean(record.hasSignature),
        signatureFailed: signatureResult.status === "rejected",
      });
      if (missing.length) setPreviewError(partialPreviewMessage(missing));
    } catch (requestError: unknown) {
      if (generation !== previewGeneration.current) return;
      setPreviewError(
        describeKycPreviewFailure(requestError, getApiErrorMessage(requestError, "")),
      );
    } finally {
      if (generation === previewGeneration.current) setFileLoading(false);
    }
  }

  async function openReview(record: KycSubmissionView) {
    if (reviewLock.current) return;
    setReviewing(record);
    setNote(record.reviewNote || "");
    await loadFile(record);
  }

  function closeReview() {
    if (reviewLock.current) return;
    previewGeneration.current += 1;
    setReviewing(null);
    setFiles(EMPTY_FILES);
    setNote("");
    setPreviewError("");
  }

  async function submitReview(decision: KycDecision) {
    if (
      !reviewing ||
      !canSubmitKycReview({
        status: reviewing.status,
        hasFrontFile: Boolean(files.front),
        fileLoading,
        saving: reviewSaving,
        decision,
        note,
      })
    ) {
      return;
    }
    if (!acquireReviewLock(reviewLock)) return;
    setReviewSaving(true);
    try {
      await api.patch("/kyc/business/review", buildKycReviewBody(reviewing.id, decision, note));
      message.success(
        decision === "APPROVED" ? KYC_REVIEW_COPY.approveSuccess : KYC_REVIEW_COPY.rejectSuccess,
      );
      previewGeneration.current += 1;
      setReviewing(null);
      setFiles(EMPTY_FILES);
      setNote("");
      setPreviewError("");
      await loadItems();
    } catch (requestError: unknown) {
      message.error(getApiErrorMessage(requestError, "") || KYC_REVIEW_COPY.reviewFailure);
    } finally {
      releaseReviewLock(reviewLock);
      setReviewSaving(false);
    }
  }

  return (
    <AdminShell>
      <Space orientation="vertical" size="large" style={{ width: "100%" }}>
        <OpsPageHeader
          title={KYC_REVIEW_COPY.title}
          crumbs={[{ title: "我的客户" }, { title: KYC_REVIEW_COPY.title }]}
          description={KYC_REVIEW_COPY.description}
        />
        <KycReviewList
          items={items}
          loading={loading}
          error={listError}
          onRetry={loadItems}
          onOpen={openReview}
          busy={reviewSaving}
        />
      </Space>
      <KycReviewModal
        open={!!reviewing}
        submission={reviewing}
        files={files}
        fileLoading={fileLoading}
        previewError={previewError}
        note={note}
        onNoteChange={setNote}
        saving={reviewSaving}
        onClose={closeReview}
        onRetryPreview={() => {
          if (reviewing) void loadFile(reviewing);
        }}
        onSubmit={submitReview}
      />
    </AdminShell>
  );
}
