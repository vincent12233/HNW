import type { BackendRole } from './backend-role';

export type OpsActionRegistration = {
  id: string;
  module: string;
  roles: readonly BackendRole[];
  eligibleStates: readonly string[];
  mutation: boolean;
  requiresReason: boolean;
  requiresConfirmation: boolean;
  idempotency: string | null;
  auditEvent: string | null;
  recovery: string;
};

export const opsActionRegistry: readonly OpsActionRegistration[] = [
  {
    id: 'kyc.approve', module: 'kyc', roles: ['BUSINESS', 'MANAGER'], eligibleStates: ['PENDING'],
    mutation: true, requiresReason: true, requiresConfirmation: true,
    idempotency: 'submission id + target state', auditEvent: 'KYC_REVIEWED',
    recovery: 'On conflict or unknown result, refresh the submission before another decision.',
  },
  {
    id: 'kyc.reject', module: 'kyc', roles: ['BUSINESS', 'MANAGER'], eligibleStates: ['PENDING'],
    mutation: true, requiresReason: true, requiresConfirmation: true,
    idempotency: 'submission id + target state', auditEvent: 'KYC_REVIEWED',
    recovery: 'Keep the note and refresh current state; never display success before confirmation.',
  },
  {
    id: 'deposits.credit', module: 'funding', roles: ['ADMIN', 'FINANCE', 'SUPPORT'], eligibleStates: ['PENDING'],
    mutation: true, requiresReason: true, requiresConfirmation: true,
    idempotency: 'deposit order number', auditEvent: 'DEPOSIT_CREDITED',
    recovery: 'Reload the deposit and ledger; do not submit a second credit when the result is unknown.',
  },
  {
    id: 'withdrawals.approve', module: 'funding', roles: ['ADMIN', 'FINANCE'], eligibleStates: ['PENDING'],
    mutation: true, requiresReason: true, requiresConfirmation: true,
    idempotency: 'withdrawal order number + decision', auditEvent: 'WITHDRAWAL_REVIEWED',
    recovery: 'Reload request, frozen funds, and ledger before retrying.',
  },
  {
    id: 'withdrawals.reject', module: 'funding', roles: ['ADMIN', 'FINANCE'], eligibleStates: ['PENDING'],
    mutation: true, requiresReason: true, requiresConfirmation: true,
    idempotency: 'withdrawal order number + decision', auditEvent: 'WITHDRAWAL_REVIEWED',
    recovery: 'Reload request and frozen-fund release before retrying.',
  },
  {
    id: 'staff.authenticator-reset', module: 'personnel', roles: ['ADMIN', 'MANAGER'], eligibleStates: ['ACTIVE'],
    mutation: true, requiresReason: true, requiresConfirmation: true,
    idempotency: 'staff id + reset request id', auditEvent: 'STAFF_TOTP_RESET',
    recovery: 'Verify the scoped staff status and audit log before issuing another reset.',
  },
  {
    id: 'orders.view', module: 'orders', roles: ['ADMIN', 'MANAGER', 'BUSINESS', 'FINANCE', 'SUPPORT'],
    eligibleStates: ['OPEN', 'PARTIALLY_FILLED', 'FILLED', 'CANCELLED', 'REJECTED', 'EXPIRED'],
    mutation: false, requiresReason: false, requiresConfirmation: false, idempotency: null,
    auditEvent: null, recovery: 'Refresh the read-only order list.',
  },
] as const;

export function actionAllowed(id: string, role: BackendRole, state: string) {
  const action = opsActionRegistry.find((entry) => entry.id === id);
  return Boolean(action && action.roles.includes(role) && action.eligibleStates.includes(state));
}
