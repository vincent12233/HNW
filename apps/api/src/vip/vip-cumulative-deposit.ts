import { Prisma } from '../generated/prisma/client';
import { moneyDecimal } from '../common/money';

type DepositQueryClient = {
  depositRequest: {
    aggregate: (args: {
      where: { accountId: string; status: 'APPROVED' };
      _sum: { amount: true };
    }) => Promise<{ _sum: { amount: Prisma.Decimal | null } }>;
  };
  accountTransaction: {
    aggregate: (args: {
      where: {
        accountId: string;
        type: 'ADMIN_CREDIT';
        status: 'COMPLETED';
        createdBy: { is: { role: { in: ['FINANCE', 'SUPPORT'] } } };
      };
      _sum: { amount: true };
    }) => Promise<{ _sum: { amount: Prisma.Decimal | null } }>;
  };
};

/**
 * Confirmed customer recharge only:
 * - approved DepositRequest amounts (full confirmed receipt, including
 *   portions later applied to IPO debt)
 * - completed ADMIN_CREDIT rows created by FINANCE or SUPPORT 上分
 *
 * Excludes pending/rejected deposits, withdrawals, ADMIN four-eyes
 * credits, ADMIN_DEBIT, trade/loan/OTC/IPO ledger types, and cash balance.
 */
export async function sumCumulativeConfirmedDeposit(
  db: DepositQueryClient,
  accountId: string | null | undefined,
): Promise<Prisma.Decimal> {
  if (!accountId) return moneyDecimal(0);
  const [approvedDeposits, operatorCredits] = await Promise.all([
    db.depositRequest.aggregate({
      where: { accountId, status: 'APPROVED' },
      _sum: { amount: true },
    }),
    db.accountTransaction.aggregate({
      where: {
        accountId,
        type: 'ADMIN_CREDIT',
        status: 'COMPLETED',
        createdBy: { is: { role: { in: ['FINANCE', 'SUPPORT'] } } },
      },
      _sum: { amount: true },
    }),
  ]);
  return moneyDecimal(approvedDeposits._sum.amount ?? 0).add(
    moneyDecimal(operatorCredits._sum.amount ?? 0),
  );
}
