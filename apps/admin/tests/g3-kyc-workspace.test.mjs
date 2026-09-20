import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  KYC_DECISIONS,
  KYC_REVIEW_COPY,
  KYC_STATUSES,
  canSubmitKycReview,
  describeKycPreviewFailure,
  kycConfirmSummary,
  kycHasReviewerFields,
  kycWorkflowForRole,
} from '../lib/kyc-review.ts';
import { maskOpsPhone } from '../lib/ops-directory.ts';

const root = dirname(fileURLToPath(import.meta.url));
const read = (relative) => readFileSync(join(root, relative), 'utf8');

const PII_LOG = /console\.(log|debug|info|warn|error)\([^)]*(phone|accountNumber|filePath|contentBase64|Aadhaar|PAN)/i;
const NEW_STATE = /REQUEST_CHANGES|NEEDS_MORE_INFO|RESUBMITTED|KYC_OTP/;
const FORBIDDEN_PRODUCT = /客户经理|服务请求|工单系统|OCR 扫描|活体识别动画|人脸识别动画/;

test('G.3 phone masking and reviewer honesty stay display-only', () => {
  assert.equal(maskOpsPhone('9876543210'), '******3210');
  assert.equal(kycHasReviewerFields([{ id: 'a', status: 'PENDING', createdAt: '', userId: 'u', fullName: 'A', documentType: 'PAN', fileName: 'f' }]), false);
  assert.equal(
    kycHasReviewerFields([
      {
        id: 'a',
        status: 'APPROVED',
        createdAt: '',
        userId: 'u',
        fullName: 'A',
        documentType: 'PAN',
        fileName: 'f',
        reviewedAt: '2026-09-20T00:00:00.000Z',
      },
    ]),
    true,
  );
});

test('G.3 preview errors distinguish forbidden from retryable failure', () => {
  assert.equal(describeKycPreviewFailure({ response: { status: 403 } }), KYC_REVIEW_COPY.previewForbidden);
  assert.equal(describeKycPreviewFailure({ response: { status: 401 } }), KYC_REVIEW_COPY.previewForbidden);
  assert.equal(describeKycPreviewFailure({ response: { status: 500 } }, 'mapped'), 'mapped');
  assert.equal(describeKycPreviewFailure({}), KYC_REVIEW_COPY.previewError);
});

test('G.3 approve and reject confirm copy names the customer and current status', () => {
  const pending = {
    id: 'kyc-1',
    documentType: 'PAN',
    status: 'PENDING',
    fileName: 'front.png',
    createdAt: '2026-09-20T00:00:00.000Z',
    userId: 'user-1',
    fullName: 'Test Applicant',
  };
  assert.match(kycConfirmSummary(pending, 'APPROVED'), /Test Applicant/);
  assert.match(kycConfirmSummary(pending, 'APPROVED'), /待审核/);
  assert.match(kycConfirmSummary(pending, 'REJECTED'), /已拒绝/);
  assert.equal(canSubmitKycReview({
    status: 'PENDING',
    hasFrontFile: true,
    fileLoading: true,
    saving: false,
    decision: 'APPROVED',
    note: '',
  }), false);
  assert.equal(canSubmitKycReview({
    status: 'PENDING',
    hasFrontFile: true,
    fileLoading: false,
    saving: true,
    decision: 'REJECTED',
    note: '影像不清晰',
  }), false);
});

test('G.3 KYC list uses G.1 chrome, loaded-result filters, and does not invent reviewer columns', () => {
  const source = read('../components/KycReviewList.tsx');
  assert.match(source, /OpsEmpty/);
  assert.match(source, /OpsErrorState/);
  assert.match(source, /OpsToolbar/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /useDebouncedValue/);
  assert.match(source, /LOADED_FILTER_CAPTION/);
  assert.match(source, /kycHasReviewerFields/);
  assert.match(source, /scroll=\{\{/);
  assert.match(source, /aria-label="刷新 KYC 列表"/);
  assert.match(source, /aria-label=\{[\s\S]*审核/);
  assert.doesNotMatch(source, /kind="tier"/);
  assert.doesNotMatch(source, NEW_STATE);
  assert.doesNotMatch(source, PII_LOG);
  assert.doesNotMatch(source, FORBIDDEN_PRODUCT);
});

test('G.3 KYC detail keeps six steps, confirmation, and no auto-download', () => {
  const source = read('../components/KycReviewModal.tsx');
  assert.match(source, /KYC_REVIEW_COPY\.stepProfile/);
  assert.match(source, /KYC_REVIEW_COPY\.stepDocuments/);
  assert.match(source, /KYC_REVIEW_COPY\.stepSelfie/);
  assert.match(source, /KYC_REVIEW_COPY\.stepSignature/);
  assert.match(source, /KYC_REVIEW_COPY\.stepBank/);
  assert.match(source, /KYC_REVIEW_COPY\.stepReview/);
  assert.match(source, /kyc-preview-skeleton/);
  assert.match(source, /重新加载证件预览/);
  assert.match(source, /aria-label="通过该 KYC 提交"/);
  assert.match(source, /aria-label="拒绝该 KYC 提交"/);
  assert.match(source, /htmlFor=\{noteId\}/);
  assert.match(source, /确认通过|确认拒绝/);
  assert.match(source, /zIndex=\{2100\}/);
  assert.match(source, /kycConfirmSummary/);
  assert.match(source, /confirmLoading=\{saving\}/);
  assert.doesNotMatch(source, /setPendingDecision\(null\);\s*\n\s*onSubmit/);
  assert.doesNotMatch(source, /onSubmit\(pendingDecision\);\s*\n\s*setPendingDecision\(null\)/);
  assert.doesNotMatch(source, /download=/);
  assert.doesNotMatch(source, /扫描线|人脸识别|自动验证动画/);
  assert.doesNotMatch(source, NEW_STATE);
  assert.doesNotMatch(source, PII_LOG);
  assert.doesNotMatch(source, /\bOTP\b/);
});

test('G.3 status tag uses text plus icon plus color and 需补件 remains a REJECTED hint', () => {
  const source = read('../components/KycStatusTag.tsx');
  assert.match(source, /OpsStatusTag/);
  assert.match(source, /resubmitHint/);
  assert.doesNotMatch(source, NEW_STATE);
  assert.deepEqual([...KYC_STATUSES], ['PENDING', 'APPROVED', 'REJECTED']);
  assert.deepEqual([...KYC_DECISIONS], ['APPROVED', 'REJECTED']);
});

test('G.3 business and manager pages keep existing review APIs', () => {
  const business = read('../app/business-kyc/page.tsx');
  const team = read('../app/team/page.tsx');
  assert.match(business, /\/kyc\/business\/pending/);
  assert.match(business, /\/kyc\/business\/\$\{record\.id\}\/file\?side=/);
  assert.match(business, /\/kyc\/business\/review/);
  assert.match(business, /describeKycPreviewFailure/);
  assert.match(business, /acquireReviewLock/);
  assert.doesNotMatch(business, /\/team\/\$\{/);
  assert.doesNotMatch(business, /\bOTP\b|verificationCode/);
  assert.doesNotMatch(business, PII_LOG);
  assert.match(team, /\/team\/\$\{record\.ownerStaffId\}\/kyc\/\$\{record\.id\}\/file\?side=/);
  assert.match(team, /\/team\/\$\{reviewing\.ownerStaffId\}\/kyc/);
  assert.match(team, /describeKycPreviewFailure/);
  assert.doesNotMatch(team, /\/kyc\/business/);
  assert.doesNotMatch(team, /\bOTP\b/);
  assert.doesNotMatch(team, PII_LOG);
});

test('G.3 does not grant ADMIN or FINANCE new KYC review routes', () => {
  assert.equal(kycWorkflowForRole('ADMIN').page, null);
  assert.equal(kycWorkflowForRole('FINANCE').page, null);
  assert.equal(kycWorkflowForRole('CLIENT').page, null);
  assert.equal(kycWorkflowForRole('BUSINESS').page, '/business-kyc');
  assert.equal(kycWorkflowForRole('SUPPORT').reviewApi, '/kyc/business/review');
  assert.equal(kycWorkflowForRole('MANAGER').page, '/team?view=kyc');
  const shell = read('../components/AdminShell.tsx');
  const block = shell.slice(
    shell.indexOf('const menus: Record<Role, MenuItemDef[]>'),
    shell.indexOf('const menuGroups'),
  );
  const adminBlock = block.slice(block.indexOf('ADMIN:'), block.indexOf('MANAGER:'));
  const financeBlock = block.slice(block.indexOf('FINANCE:'), block.indexOf('SUPPORT:'));
  assert.doesNotMatch(adminBlock, /\/business-kyc|view=kyc/);
  assert.doesNotMatch(financeBlock, /\/business-kyc|view=kyc/);
});

test('G.3 CSS keeps reduced motion and wrap for long KYC notes', () => {
  const css = read('../app/globals.css');
  assert.match(css, /\.kyc-wrap-text/);
  assert.match(css, /\.kyc-preview-skeleton/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /\.kyc-preview-skeleton/);
  assert.match(css, /kyc-review-workspace \.ops-status-tag/);
});
