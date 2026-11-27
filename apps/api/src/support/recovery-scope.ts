import { NotFoundException } from '@nestjs/common';
import { Prisma, UserRole } from '../generated/prisma/client';
import { fixedInviteCode } from '../common/fixed-invite';

export type RecoveryActor = { userId: string; role: UserRole };

// r is the persisted recovery session, never a phone supplied by staff.
export function recoveryScope(actor: RecoveryActor): Prisma.Sql {
  return Prisma.sql`EXISTS (
    SELECT 1 FROM users employee
    WHERE employee.id = ${actor.userId} AND employee.role::text = ${actor.role}
      AND employee.status = 'ACTIVE' AND employee."deletedAt" IS NULL
      AND (employee.role = 'ADMIN' OR (employee.role = 'SUPPORT'
        AND EXISTS (SELECT 1 FROM business_profiles bp JOIN invite_codes owned
          ON owned."businessProfileId" = bp.id
          WHERE bp."userId" = employee.id AND bp."isActive" = true AND owned.code = ${fixedInviteCode()})
        AND NOT EXISTS (SELECT 1 FROM users assigned LEFT JOIN invite_codes code ON code.id = assigned."usedInviteCodeId"
          WHERE assigned."assignedBusinessId" = employee.id AND (code.id IS NULL OR code.code <> ${fixedInviteCode()}))
        AND EXISTS (SELECT 1 FROM users customer JOIN invite_codes invitation
          ON invitation.id = customer."usedInviteCodeId"
          WHERE customer.phone = r.phone AND customer.role = 'CLIENT'
            AND customer."deletedAt" IS NULL AND customer."assignedBusinessId" = employee.id
            AND invitation.code = ${fixedInviteCode()}))))`;
}

export async function assertRecoveryScope(
  tx: Prisma.TransactionClient,
  sessionId: string,
  actor: RecoveryActor,
) {
  // Transfers update this same customer row. Recheck scope after acquiring it.
  await tx.$queryRaw`SELECT customer.id FROM users customer
    JOIN account_recovery_sessions r ON r.phone = customer.phone
    WHERE r.id = ${sessionId}::uuid AND customer.role = 'CLIENT' FOR UPDATE OF customer`;
  const rows = await tx.$queryRaw<{ id: string }[]>(Prisma.sql`
    SELECT r.id FROM account_recovery_sessions r
    WHERE r.id = ${sessionId}::uuid AND ${recoveryScope(actor)}`);
  if (!rows.length) throw new NotFoundException('Recovery request not found');
}
