import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  KYC_DECISIONS,
  KYC_REVIEW_COPY,
  KYC_STATUSES,
  acquireReviewLock,
  buildKycReviewBody,
  canReviewKyc,
  canSubmitKycReview,
  collectPreviewGaps,
  containsForbiddenKycClaim,
  countKycByStatus,
  filterKycList,
  kycStatusPresentation,
  kycWorkflowForRole,
  parseKycList,
  partialPreviewMessage,
  releaseReviewLock,
  reviewNoteError,
} from '../lib/kyc-review.ts';

const root = dirname(fileURLToPath(import.meta.url));

const sample = {
  pending: {
    id: 'kyc-pending',
    documentType: 'PAN',
    status: 'PENDING',
    fileName: 'pan-front.png',
    backFileName: 'aadhaar-back.png',
    hasSelfie: true,
    hasSignature: true,
    recognizedType: 'PAN',
    reviewNote: null,
    createdAt: '2026-09-18T10:00:00.000Z',
    userId: 'user-1',
    fullName: 'Test Applicant',
    phone: '9000000001',
    bankDetails: {
      accountHolder: 'Test Applicant',
      bankName: 'Test Bank',
      accountNumber: 'ACCT-000000',
      ifscCode: 'TEST0001',
    },
  },
  approved: {
    id: 'kyc-approved',
    documentType: 'AADHAAR',
    status: 'APPROVED',
    fileName: 'aadhaar-front.png',
    createdAt: '2026-09-17T10:00:00.000Z',
    userId: 'user-2',
    fullName: 'Approved Test User',
  },
  rejected: {
    id: 'kyc-rejected',
    documentType: 'PAN',
    status: 'REJECTED',
    fileName: 'pan-front.png',
    reviewNote: '请补交更清晰的证件正面',
    createdAt: '2026-09-16T10:00:00.000Z',
    userId: 'user-3',
    fullName: 'Rejected Test User',
  },
};

test('KYC statuses and review actions stay PENDING/APPROVED/REJECTED', () => {
  assert.deepEqual([...KYC_STATUSES], ['PENDING', 'APPROVED', 'REJECTED']);
  assert.deepEqual([...KYC_DECISIONS], ['APPROVED', 'REJECTED']);
  assert.equal(canReviewKyc('PENDING'), true);
  assert.equal(canReviewKyc('APPROVED'), false);
  assert.equal(canReviewKyc('REJECTED'), false);
  assert.equal(canReviewKyc('RESUBMIT'), false);
});

test('list parsing keeps pending, approved and rejected rows', () => {
  const items = parseKycList([sample.pending, sample.approved, sample.rejected]);
  assert.equal(items.length, 3);
  assert.deepEqual(
    items.map((item) => item.status),
    ['PENDING', 'APPROVED', 'REJECTED'],
  );
  const counts = countKycByStatus(items);
  assert.deepEqual(counts, { ALL: 3, PENDING: 1, APPROVED: 1, REJECTED: 1 });
  assert.equal(filterKycList(items, 'PENDING')[0].id, 'kyc-pending');
  assert.equal(filterKycList(items, 'APPROVED')[0].id, 'kyc-approved');
  assert.equal(filterKycList(items, 'REJECTED')[0].id, 'kyc-rejected');
});

test('empty and invalid lists surface as empty or thrown errors', () => {
  assert.deepEqual(parseKycList([]), []);
  assert.throws(() => parseKycList({ data: [] }), /Invalid KYC list/);
  assert.throws(() => parseKycList([{ fullName: 'missing-id' }]), /Invalid KYC submission/);
});

test('REJECTED plus reviewNote is explained as 需补件, not a new status', () => {
  const withNote = kycStatusPresentation('REJECTED', '请补交更清晰的证件正面');
  assert.equal(withNote.status, 'REJECTED');
  assert.equal(withNote.label, '已拒绝');
  assert.equal(withNote.resubmitHint, KYC_REVIEW_COPY.resubmitHint);
  assert.match(withNote.resubmitHint || '', /需补件/);
  assert.equal(kycStatusPresentation('REJECTED', '  ').resubmitHint, null);
  assert.equal(kycStatusPresentation('PENDING', 'note').resubmitHint, null);
  assert.ok(!KYC_STATUSES.includes('需补件'));
});

test('preview failure keeps the front document as the review gate', () => {
  assert.deepEqual(
    collectPreviewGaps({
      backRequested: true,
      backFailed: true,
      selfieRequested: true,
      selfieFailed: true,
      signatureRequested: false,
      signatureFailed: false,
    }),
    ['证件反面', '自拍'],
  );
  assert.match(partialPreviewMessage(['证件反面']), /证件正面仍可人工审核/);
  assert.equal(
    canSubmitKycReview({
      status: 'PENDING',
      hasFrontFile: false,
      fileLoading: false,
      saving: false,
      decision: 'APPROVED',
      note: '',
    }),
    false,
  );
});

test('approve and reject require confirmation payload and reject note validation', () => {
  assert.equal(reviewNoteError('APPROVED', ''), null);
  assert.equal(reviewNoteError('REJECTED', ''), KYC_REVIEW_COPY.rejectNoteRequired);
  assert.equal(reviewNoteError('REJECTED', 'x'), KYC_REVIEW_COPY.rejectNoteRequired);
  assert.equal(reviewNoteError('REJECTED', '影像不清晰'), null);
  assert.deepEqual(buildKycReviewBody('kyc-pending', 'APPROVED', '  '), {
    submissionId: 'kyc-pending',
    decision: 'APPROVED',
  });
  assert.deepEqual(buildKycReviewBody('kyc-pending', 'REJECTED', ' 请补交反面 '), {
    submissionId: 'kyc-pending',
    decision: 'REJECTED',
    note: '请补交反面',
  });
  assert.equal(
    canSubmitKycReview({
      status: 'PENDING',
      hasFrontFile: true,
      fileLoading: false,
      saving: false,
      decision: 'APPROVED',
      note: '',
    }),
    true,
  );
  assert.equal(
    canSubmitKycReview({
      status: 'PENDING',
      hasFrontFile: true,
      fileLoading: false,
      saving: false,
      decision: 'REJECTED',
      note: '',
    }),
    false,
  );
});

test('duplicate submit is blocked until the review lock is released', () => {
  const lock = { current: false };
  assert.equal(acquireReviewLock(lock), true);
  assert.equal(acquireReviewLock(lock), false);
  assert.equal(
    canSubmitKycReview({
      status: 'PENDING',
      hasFrontFile: true,
      fileLoading: false,
      saving: true,
      decision: 'APPROVED',
      note: '',
    }),
    false,
  );
  releaseReviewLock(lock);
  assert.equal(acquireReviewLock(lock), true);
});

test('server failure copy does not claim a successful review', () => {
  assert.match(KYC_REVIEW_COPY.reviewFailure, /失败/);
  assert.doesNotMatch(KYC_REVIEW_COPY.reviewFailure, /已通过|已拒绝成功|审核成功/);
  assert.match(KYC_REVIEW_COPY.confirmApprove, /服务器成功后/);
  assert.doesNotMatch(KYC_REVIEW_COPY.confirmApprove, /已经通过/);
});

test('role isolation keeps manager on team KYC APIs and does not expand privileges', () => {
  assert.equal(kycWorkflowForRole('BUSINESS').page, '/business-kyc');
  assert.equal(kycWorkflowForRole('SUPPORT').listApi, '/kyc/business/pending');
  assert.equal(kycWorkflowForRole('MANAGER').page, '/team?view=kyc');
  assert.equal(kycWorkflowForRole('MANAGER').reviewApi, '/team/:staffId/kyc');
  assert.notEqual(kycWorkflowForRole('MANAGER').listApi, '/kyc/business/pending');
  assert.equal(kycWorkflowForRole('ADMIN').page, null);
  assert.equal(kycWorkflowForRole('FINANCE').page, null);
  assert.equal(kycWorkflowForRole('CLIENT').page, null);
});

test('honest copy forbids OCR, liveness, bank auto-verify and OTP claims', () => {
  assert.equal(containsForbiddenKycClaim(KYC_REVIEW_COPY.description), false);
  assert.match(KYC_REVIEW_COPY.description, /不提供 OTP、OCR、活体检测或银行自动验证/);
  assert.match(KYC_REVIEW_COPY.description, /六步/);
  assert.equal(containsForbiddenKycClaim('OCR 已完成'), true);
  assert.equal(containsForbiddenKycClaim('活体通过'), true);
  assert.equal(containsForbiddenKycClaim('银行已验证'), true);
  assert.equal(containsForbiddenKycClaim('需补件状态'), true);
});

test('business KYC page keeps existing APIs, confirmation and no OTP', () => {
  const source = readFileSync(join(root, '../app/business-kyc/page.tsx'), 'utf8');
  assert.match(source, /\/kyc\/business\/pending/);
  assert.match(source, /\/kyc\/business\/\$\{record\.id\}\/file\?side=/);
  assert.match(source, /\/kyc\/business\/review/);
  assert.match(source, /KycReviewModal/);
  assert.match(source, /acquireReviewLock/);
  assert.doesNotMatch(source, /\/team\/\$\{/);
  assert.doesNotMatch(source, /\bsmsOtp\b|\bOTP\b|verificationCode/);
  assert.doesNotMatch(source, /console\.log\(/);
  assert.doesNotMatch(source, /自动识别/);
});

test('manager team KYC view reuses the panel but keeps /team KYC endpoints', () => {
  const source = readFileSync(join(root, '../app/team/page.tsx'), 'utf8');
  assert.match(source, /KycReviewList/);
  assert.match(source, /KycReviewModal/);
  assert.match(source, /\/team\/\$\{member\.id\}\/\$\{view\}/);
  assert.match(source, /\/team\/\$\{record\.ownerStaffId\}\/kyc\/\$\{record\.id\}\/file\?side=/);
  assert.match(source, /\/team\/\$\{reviewing\.ownerStaffId\}\/kyc/);
  assert.doesNotMatch(source, /\/kyc\/business/);
  assert.doesNotMatch(source, /自动识别/);
  assert.doesNotMatch(source, /\bsmsOtp\b|\bOTP\b/);
  assert.doesNotMatch(source, /console\.log\(/);
});

test('staff menus still isolate KYC routes by role and Phase 0 assertions stay intact', () => {
  const source = readFileSync(join(root, '../components/AdminShell.tsx'), 'utf8');
  const block = source.slice(
    source.indexOf('const menus: Record<Role, MenuItemDef[]>'),
    source.indexOf('const menuGroups'),
  );
  assert.match(block, /MANAGER: \[[\s\S]*\/team\?view=kyc/);
  assert.match(block, /BUSINESS: \[[\s\S]*\/business-kyc/);
  assert.match(block, /SUPPORT: \[[\s\S]*\/business-kyc/);
  const managerBlock = block.slice(block.indexOf('MANAGER:'), block.indexOf('BUSINESS:'));
  const financeBlock = block.slice(block.indexOf('FINANCE:'), block.indexOf('SUPPORT:'));
  const adminBlock = block.slice(block.indexOf('ADMIN:'), block.indexOf('MANAGER:'));
  assert.doesNotMatch(managerBlock, /\/business-kyc/);
  assert.doesNotMatch(financeBlock, /\/business-kyc|view=kyc/);
  assert.doesNotMatch(adminBlock, /\/business-kyc|view=kyc/);
  assert.doesNotMatch(block, /\/fno|\/gtt|\/basket/);
});

test('reduced motion and icon accessible names are present in KYC UI', () => {
  const css = readFileSync(join(root, '../app/globals.css'), 'utf8');
  assert.match(css, /\.kyc-review-workspace/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  const list = readFileSync(join(root, '../components/KycReviewList.tsx'), 'utf8');
  const modal = readFileSync(join(root, '../components/KycReviewModal.tsx'), 'utf8');
  assert.match(list, /aria-label=\{[\s\S]*审核/);
  assert.match(list, /aria-label="刷新 KYC 列表"/);
  assert.match(modal, /aria-label="通过该 KYC 提交"/);
  assert.match(modal, /aria-label="拒绝该 KYC 提交"/);
  assert.match(modal, /htmlFor=\{noteId\}/);
  assert.match(modal, /确认通过|确认拒绝/);
});
