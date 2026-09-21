import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { formatInr } from '../lib/ops-format.ts';
import { maskBankAccount, maskOpsPhone, maskedPayoutLabel } from '../lib/ops-directory.ts';
import { FUNDING_COPY, fundingWorkflowForRole } from '../lib/ops-funding.ts';

const root = dirname(fileURLToPath(import.meta.url));
const read = (relative) => readFileSync(join(root, relative), 'utf8');

const PII_LOG = /console\.(log|debug|info|warn|error)\([^)]*(phone|accountNumber|token|stack|ifsc|upiId)/i;
const VIP_PRIORITY = /VIP 优先|VIP限额|vipPriority|VIP 作为/;
const NEW_APPROVAL = /双人审批|dual.?approv|batch.?approv|自动到账庆祝/;
const GATEWAY = /razorpay|stripe|paytm|模拟到账/;

test('G.4 funding workflows keep FINANCE write and BUSINESS read-only', () => {
  assert.equal(fundingWorkflowForRole('FINANCE').canApproveWithdrawal, true);
  assert.equal(fundingWorkflowForRole('FINANCE').canCredit, true);
  assert.equal(fundingWorkflowForRole('BUSINESS').canApproveWithdrawal, false);
  assert.equal(fundingWorkflowForRole('BUSINESS').canCredit, false);
  assert.equal(fundingWorkflowForRole('SUPPORT').canApproveWithdrawal, false);
  assert.equal(fundingWorkflowForRole('SUPPORT').canCredit, true);
  assert.equal(fundingWorkflowForRole('ADMIN').depositsPage, null);
  assert.equal(fundingWorkflowForRole('MANAGER').withdrawalsPage, null);
});

test('G.4 bank masking and INR grouping stay display-only', () => {
  assert.equal(maskBankAccount('123456789012'), '••••9012');
  assert.match(maskedPayoutLabel({ upiId: 'customername@upi' }), /••me@upi/);
  assert.doesNotMatch(maskedPayoutLabel({ accountNumber: '123456789012', bankName: 'HDFC', ifscCode: 'HDFC0001234' }), /123456789012/);
  assert.equal(formatInr('10000000').replace(/[\s\u00a0\u202f]/g, ''), '₹1,00,00,000.00');
  assert.equal(maskOpsPhone('9876543210'), '******3210');
});

test('G.4 deposits keep pending/history PATCH APIs and confirm before credit', () => {
  const source = read('../app/deposits/page.tsx');
  assert.match(source, /OpsPageHeader/);
  assert.match(source, /OpsToolbar/);
  assert.match(source, /OpsEmpty/);
  assert.match(source, /OpsErrorState/);
  assert.match(source, /OpsStatusTag/);
  assert.match(source, /OpsMoney/);
  assert.match(source, /\/deposit\/pending/);
  assert.match(source, /\/deposit\/history/);
  assert.match(source, /\/deposit\/\$\{.*\}\/approve/);
  assert.match(source, /\/deposit\/\$\{.*\}\/reject/);
  assert.match(source, /processing\.current/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /aria-label="刷新上分订单"/);
  assert.match(source, /scroll=\{\{ x:/);
  assert.doesNotMatch(source, /`\+91 \$\{/);
  assert.doesNotMatch(source, PII_LOG);
  assert.doesNotMatch(source, VIP_PRIORITY);
  assert.doesNotMatch(source, GATEWAY);
  assert.doesNotMatch(source, /setRows\(.*APPROVED/);
});

test('G.4 withdrawals confirm approve/reject, mask payout, and keep records on failure', () => {
  const source = read('../app/withdrawals/page.tsx');
  assert.match(source, /\/withdrawal\/pending/);
  assert.match(source, /\/withdrawal\/history/);
  assert.match(source, /\/withdrawal\/\$\{record\.id\}\/approve/);
  assert.match(source, /\/withdrawal\/\$\{rejecting\.id\}\/reject/);
  assert.match(source, /确认通过提现/);
  assert.match(source, /服务器成功后刷新/);
  assert.match(source, /maskedPayoutLabel/);
  assert.match(source, /submitting\.current/);
  assert.match(source, /OpsModal/);
  assert.match(source, /zIndex=\{2100\}/);
  assert.match(source, /FUNDING_COPY\.noVipPriority/);
  assert.doesNotMatch(source, /record\.upiId\}/);
  assert.doesNotMatch(source, /record\.ifscCode\}/);
  assert.doesNotMatch(source, NEW_APPROVAL);
  assert.doesNotMatch(source, VIP_PRIORITY);
  assert.doesNotMatch(source, PII_LOG);
});

test('G.4 loans keep FINANCE mutate APIs and confirm reject/overdue', () => {
  const source = read('../app/loans/page.tsx');
  assert.match(source, /getBackendRole\(\) === 'FINANCE'/);
  assert.match(source, /api\.get<LoanRecord\[]>\("\/loans"\)/);
  assert.match(source, /\/loans\/\$\{record\.id\}\/approve/);
  assert.match(source, /\/loans\/\$\{record\.id\}\/reject/);
  assert.match(source, /\/loans\/\$\{record\.id\}\/overdue/);
  assert.match(source, /\/loans\/\$\{record\.id\}\/repay/);
  assert.match(source, /确认拒绝该贷款申请/);
  assert.match(source, /确认标记逾期/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /OpsStatusTag/);
  assert.doesNotMatch(source, /VIP 优先/);
  assert.doesNotMatch(source, PII_LOG);
});

test('G.4 business deposits and withdrawals stay GET-only without finance write', () => {
  const deposits = read('../app/business-deposits/page.tsx');
  const withdrawals = read('../app/business-withdrawals/page.tsx');
  assert.match(deposits, /\/business\/my-deposits/);
  assert.match(withdrawals, /\/business\/my-withdrawals/);
  assert.doesNotMatch(deposits, /api\.(patch|post|put|delete)/);
  assert.doesNotMatch(withdrawals, /api\.(patch|post|put|delete)/);
  assert.doesNotMatch(deposits, /\/deposit\/.*approve/);
  assert.doesNotMatch(withdrawals, /\/withdrawal\/.*approve/);
  assert.match(deposits, /maskOpsPhone/);
  assert.match(withdrawals, /maskedPayoutLabel/);
  assert.match(withdrawals, /没有审核或上分权限|不能通过或拒绝提现/);
  assert.doesNotMatch(deposits, /`\+91 \$\{/);
  assert.doesNotMatch(withdrawals, /record\.accountNumber/);
});

test('G.4 SUPPORT funds page keeps existing credit/debit and does not approve withdrawals', () => {
  const source = read('../app/business-funds/page.tsx');
  assert.match(source, /\/admin\/accounts\/\$\{encodeURIComponent\(adjustment\.accountNumber\)\}\/\$\{adjustment\.direction\}/);
  assert.match(source, /dedicatedOperator/);
  assert.match(source, /adjustmentLock\.current/);
  assert.doesNotMatch(source, /\/withdrawal\/.*approve/);
  assert.doesNotMatch(source, /\/loans\/.*approve/);
  assert.match(source, /maskOpsPhone/);
  assert.match(source, /OpsModal/);
  assert.doesNotMatch(source, VIP_PRIORITY);
  assert.match(FUNDING_COPY.noDualApproval, /单人审批/);
});

test('G.4 funding pages honor reduced motion and wrap long text', () => {
  const css = read('../app/globals.css');
  assert.match(css, /\.ops-wrap-text/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  for (const page of ['../app/deposits/page.tsx', '../app/withdrawals/page.tsx', '../app/loans/page.tsx']) {
    const source = read(page);
    assert.match(source, /ops-workspace/);
    assert.match(source, /aria-label=/);
  }
});
