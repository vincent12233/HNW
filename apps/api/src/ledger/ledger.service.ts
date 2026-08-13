import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type Tx = Prisma.TransactionClient;
type Money = Prisma.Decimal | number | string;
type JournalLine = { accountId: string; side: 'DEBIT' | 'CREDIT'; amount: Money };

@Injectable()
export class LedgerService {
  constructor(private readonly prisma: PrismaService) {}

  async ensureCustomerFundsAccount(tx: Tx, customerAccountId: string, accountNumber: string) {
    return tx.ledgerAccount.upsert({
      where: { code: `CLIENT_FUNDS:${accountNumber}` },
      update: { active: true },
      create: {
        code: `CLIENT_FUNDS:${accountNumber}`,
        name: `Client funds ${accountNumber}`,
        type: 'LIABILITY',
        customerAccountId,
      },
    });
  }

  async ensurePlatformCashAccount(tx: Tx) {
    return tx.ledgerAccount.upsert({
      where: { code: 'PLATFORM_CASH:INR' },
      update: { active: true },
      create: { code: 'PLATFORM_CASH:INR', name: 'Platform cash INR', type: 'ASSET' },
    });
  }

  async postJournal(tx: Tx, input: {
    eventType: string;
    referenceType: string;
    referenceId: string;
    idempotencyKey: string;
    description?: string;
    createdById?: string;
    lines: JournalLine[];
  }) {
    const debit = input.lines.filter((line) => line.side === 'DEBIT').reduce((sum, line) => sum.add(line.amount), new Prisma.Decimal(0));
    const credit = input.lines.filter((line) => line.side === 'CREDIT').reduce((sum, line) => sum.add(line.amount), new Prisma.Decimal(0));
    if (input.lines.length < 2 || debit.lte(0) || !debit.equals(credit)) {
      throw new BadRequestException('Ledger journal is not balanced');
    }
    return tx.ledgerJournal.create({
      data: {
        journalNo: `JRN${Date.now()}${Math.random().toString(36).slice(2, 7).toUpperCase()}`,
        eventType: input.eventType,
        referenceType: input.referenceType,
        referenceId: input.referenceId,
        idempotencyKey: input.idempotencyKey,
        description: input.description,
        createdById: input.createdById,
        entries: { create: input.lines.map((line) => ({ ledgerAccountId: line.accountId, side: line.side, amount: line.amount })) },
      },
      include: { entries: true },
    });
  }

  async postCustomerCash(tx: Tx, input: {
    direction: 'IN' | 'OUT';
    customerAccountId: string;
    accountNumber: string;
    amount: Money;
    eventType: string;
    referenceType: string;
    referenceId: string;
    createdById?: string;
  }) {
    const cash = await this.ensurePlatformCashAccount(tx);
    const client = await this.ensureCustomerFundsAccount(tx, input.customerAccountId, input.accountNumber);
    return this.postJournal(tx, {
      eventType: input.eventType,
      referenceType: input.referenceType,
      referenceId: input.referenceId,
      idempotencyKey: `${input.referenceType}:${input.referenceId}:${input.eventType}`,
      createdById: input.createdById,
      lines: input.direction === 'IN'
        ? [{ accountId: cash.id, side: 'DEBIT', amount: input.amount }, { accountId: client.id, side: 'CREDIT', amount: input.amount }]
        : [{ accountId: client.id, side: 'DEBIT', amount: input.amount }, { accountId: cash.id, side: 'CREDIT', amount: input.amount }],
    });
  }

  async reconciliation() {
    const rows = await this.prisma.$queryRaw<Array<{ accountId: string; accountNumber: string; operational: Prisma.Decimal; ledger: Prisma.Decimal }>>`
      SELECT a.id AS "accountId", a."accountNumber", a."cashBalance" AS operational,
        COALESCE(SUM(CASE WHEN le.side = 'CREDIT' THEN le.amount ELSE -le.amount END), 0) AS ledger
      FROM accounts a
      LEFT JOIN ledger_accounts la ON la."customerAccountId" = a.id AND la.type = 'LIABILITY'
      LEFT JOIN ledger_entries le ON le."ledgerAccountId" = la.id
      GROUP BY a.id, a."accountNumber", a."cashBalance"
    `;
    return rows.map((row) => ({
      accountId: row.accountId,
      accountNumber: row.accountNumber,
      operationalBalance: row.operational.toFixed(2),
      ledgerBalance: row.ledger.toFixed(2),
      difference: row.operational.sub(row.ledger).toFixed(2),
      balanced: row.operational.equals(row.ledger),
    }));
  }
}
