import { randomBytes } from 'crypto';
import * as bcrypt from 'bcrypt';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { availableCash, moneyDecimal } from '../common/money';

export const PHASE4A_FIXED_INVITE = 'PHASE4AFIXEDINV12';
export const WITHDRAWAL_PIN = '123456';

export type FundingBalances = {
  cashBalance: string;
  buyingPower: string;
  frozenBalance: string;
};

export const DEFAULT_BALANCES: FundingBalances = {
  cashBalance: '1000.00',
  buyingPower: '800.00',
  frozenBalance: '200.00',
};

export function token(prefix: string) {
  return `${prefix}${randomBytes(6).toString('hex').toUpperCase()}`;
}

export async function createStaffUser(
  prisma: PrismaService,
  role: 'FINANCE' | 'SUPPORT' | 'BUSINESS',
) {
  const suffix = token('');
  return prisma.user.create({
    data: {
      email: `phase4a-${role.toLowerCase()}-${suffix}@example.test`,
      passwordHash: 'not-used',
      fullName: `Phase4A ${role}`,
      phone: `91${suffix.slice(0, 10).padEnd(10, '0')}`,
      customerNo: `P4A${role[0]}${suffix}`,
      role,
      status: 'ACTIVE',
    },
  });
}

export async function createInviteGraph(
  prisma: PrismaService,
  businessUserId: string,
  code: string,
) {
  const profile = await prisma.businessProfile.create({
    data: {
      userId: businessUserId,
      employeeNo: token('EMP'),
      isActive: true,
    },
  });
  return prisma.inviteCode.create({
    data: {
      code,
      businessProfileId: profile.id,
      status: 'USED',
    },
  });
}

export async function createClientWithAccount(
  prisma: PrismaService,
  options: {
    inviteCodeId: string;
    assignedBusinessId?: string;
    balances?: FundingBalances;
    withWithdrawalPin?: boolean;
  },
) {
  const suffix = token('');
  const pinHash = options.withWithdrawalPin
    ? await bcrypt.hash(WITHDRAWAL_PIN, 4)
    : null;
  const user = await prisma.user.create({
    data: {
      email: `phase4a-client-${suffix}@example.test`,
      passwordHash: 'not-used',
      fullName: 'Phase4A Client',
      phone: `90${suffix.slice(0, 10).padEnd(10, '0')}`,
      customerNo: `P4AC${suffix}`,
      role: 'CLIENT',
      status: 'ACTIVE',
      usedInviteCodeId: options.inviteCodeId,
      assignedBusinessId: options.assignedBusinessId,
      withdrawalPinHash: pinHash,
    },
  });
  const balances = options.balances ?? DEFAULT_BALANCES;
  const account = await prisma.account.create({
    data: {
      accountNumber: `HNW${suffix}`,
      userId: user.id,
      cashBalance: new Prisma.Decimal(balances.cashBalance),
      buyingPower: new Prisma.Decimal(balances.buyingPower),
      frozenBalance: new Prisma.Decimal(balances.frozenBalance),
      currency: 'INR',
      isLive: true,
    },
  });
  return { user, account };
}

export async function snapshotAccount(
  prisma: PrismaService,
  accountId: string,
) {
  const account = await prisma.account.findUniqueOrThrow({
    where: { id: accountId },
  });
  return {
    cashBalance: moneyDecimal(account.cashBalance),
    buyingPower: moneyDecimal(account.buyingPower),
    frozenBalance: moneyDecimal(account.frozenBalance),
    available: availableCash(account),
  };
}

export function assertFundingInvariants(account: {
  cashBalance: Prisma.Decimal;
  buyingPower: Prisma.Decimal;
  frozenBalance: Prisma.Decimal;
}) {
  if (account.cashBalance.lt(0)) {
    throw new Error(`negative cashBalance ${account.cashBalance.toFixed(2)}`);
  }
  if (account.buyingPower.lt(0)) {
    throw new Error(`negative buyingPower ${account.buyingPower.toFixed(2)}`);
  }
  if (account.frozenBalance.lt(0)) {
    throw new Error(
      `negative frozenBalance ${account.frozenBalance.toFixed(2)}`,
    );
  }
  if (availableCash(account).lt(0)) {
    throw new Error('negative availableCash');
  }
}

export async function cleanupPhase4A(prisma: PrismaService) {
  const users = await prisma.user.findMany({
    where: { email: { startsWith: 'phase4a-' } },
    select: { id: true },
  });
  const ids = users.map((user) => user.id);
  if (ids.length === 0) return;
  await prisma.auditLog.deleteMany({ where: { actorId: { in: ids } } });
  await prisma.notification.deleteMany({ where: { userId: { in: ids } } });
  await prisma.user.updateMany({
    where: { id: { in: ids } },
    data: { usedInviteCodeId: null, assignedBusinessId: null },
  });
  await prisma.user.deleteMany({ where: { id: { in: ids } } });
}

export class ThrowingAuditService {
  createLog(): Promise<never> {
    return Promise.reject(new Error('audit insert failed'));
  }
}

export function interceptLedgerCreate(
  prisma: PrismaService,
  fail: () => boolean,
) {
  const original = prisma.$transaction.bind(prisma);
  (prisma as any).$transaction = (
    fn: (tx: any) => Promise<unknown>,
    options?: unknown,
  ) =>
    original(async (tx: any) => {
      const proxied = new Proxy(tx, {
        get(target, prop, receiver) {
          if (prop === 'accountTransaction') {
            return new Proxy(target.accountTransaction, {
              get(inner, innerProp, innerReceiver) {
                if (innerProp === 'create' && fail()) {
                  return async () => {
                    throw new Error('ledger insert failed');
                  };
                }
                return Reflect.get(inner, innerProp, innerReceiver);
              },
            });
          }
          return Reflect.get(target, prop, receiver);
        },
      });
      return fn(proxied);
    }, options as never);
  return () => {
    (prisma as any).$transaction = original;
  };
}
