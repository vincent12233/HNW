import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { WithdrawalPinService } from '../client-experience/withdrawal-pin.service';

@Injectable()
export class WithdrawalService {
  private static readonly MINIMUM_WITHDRAWAL_AMOUNT = 100;
  private static readonly MAXIMUM_WITHDRAWAL_AMOUNT = 9_999_999_999_999.99;
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly pins: WithdrawalPinService,
  ) {}

  async createRequest(
    userId: string,
    amount: number,
    bankName?: string,
    accountNumber?: string,
    ifscCode?: string,
    upiId?: string,
    note?: string,
    withdrawalPin?: string,
  ) {
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Amount must be greater than zero');
    }

    if (amount < WithdrawalService.MINIMUM_WITHDRAWAL_AMOUNT) {
      throw new BadRequestException('Minimum withdrawal amount is ₹100');
    }

    if (amount > WithdrawalService.MAXIMUM_WITHDRAWAL_AMOUNT) {
      throw new BadRequestException('Withdrawal amount exceeds the limit');
    }

    const normalizedAmount = Math.round((amount + Number.EPSILON) * 100) / 100;
    if (Math.abs(amount - normalizedAmount) > 1e-9) {
      throw new BadRequestException(
        'Withdrawal amount cannot have more than two decimal places',
      );
    }
    amount = normalizedAmount;

    if (!upiId && (!bankName || !accountNumber || !ifscCode)) {
      throw new BadRequestException(
        'Provide either UPI ID or complete bank details',
      );
    }

    await this.pins.verify(userId, withdrawalPin);
    return this.prisma.$transaction(
      async (tx) => {
        const account = await tx.account.findUnique({ where: { userId } });
        if (!account) {
          throw new NotFoundException('Account not found');
        }

        if (
          Number(account.cashBalance) < amount ||
          Number(account.buyingPower) < amount
        ) {
          throw new BadRequestException(
            'Insufficient available balance',
          );
        }

        const request = await tx.withdrawalRequest.create({
          data: {
            orderNo: this.generateOrderNo(),
            accountId: account.id,
            amount,
            frozenAmount: amount,
            bankName: bankName?.trim() || null,
            accountNumber: accountNumber?.trim() || null,
            ifscCode: ifscCode?.trim().toUpperCase() || null,
            upiId: upiId?.trim() || null,
            note: note?.trim() || null,
            status: 'PENDING',
          },
        });
        await tx.account.update({
          where: { id: account.id },
          data: {
            buyingPower: { decrement: amount },
            frozenBalance: { increment: amount },
          },
        });
        await tx.notification.create({
          data: {
            userId,
            type: 'WITHDRAWAL',
            title: 'Withdrawal submitted',
            body: `${request.orderNo} is pending review. The requested funds are frozen.`,
            referenceId: request.id,
          },
        });
        return request;
      },
      { isolationLevel: 'Serializable' },
    );
  }

  async myWithdrawals(userId: string) {
    const account = await this.prisma.account.findUnique({
      where: { userId },
      select: { id: true },
    });

    if (!account) {
      throw new NotFoundException('Account not found');
    }

    return this.prisma.withdrawalRequest.findMany({
      where: { accountId: account.id },
      orderBy: { createdAt: 'desc' },
    });
  }

  async listPendingWithdrawals(role?: string) {
    const fixedCode = process.env.ADMIN_FIXED_INVITE_CODE?.trim().toUpperCase() || 'ADMINFIXED2026';
    return this.prisma.withdrawalRequest.findMany({
      where: {
        status: 'PENDING',
        ...(role === 'FINANCE' ? { account: { user: { usedInviteCode: { code: { not: fixedCode } } } } } : {}),
      },
      include: {
        account: {
          include: {
            user: {
              select: {
                id: true,
                customerNo: true,
                fullName: true,
                phone: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async listWithdrawalHistory(role?: string, status?: string) {
    const normalized = String(status ?? 'ALL').trim().toUpperCase();
    const allowed = new Set(['ALL', 'PENDING', 'APPROVED', 'REJECTED']);
    if (!allowed.has(normalized)) {
      throw new BadRequestException('Invalid withdrawal status filter');
    }

    const fixedCode = process.env.ADMIN_FIXED_INVITE_CODE?.trim().toUpperCase() || 'ADMINFIXED2026';
    return this.prisma.withdrawalRequest.findMany({
      where: {
        ...(normalized === 'ALL' ? {} : { status: normalized as 'PENDING' | 'APPROVED' | 'REJECTED' }),
        ...(role === 'FINANCE' ? { account: { user: { usedInviteCode: { code: { not: fixedCode } } } } } : {}),
      },
      include: {
        account: {
          include: {
            user: {
              select: {
                id: true,
                customerNo: true,
                fullName: true,
                phone: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  async approveWithdrawal(withdrawalId: string, actorId?: string, role?: string) {
    const result = await this.prisma.$transaction(async (tx) => {
      const withdrawal = await tx.withdrawalRequest.findUnique({
        where: { id: withdrawalId },
      });

      if (!withdrawal) {
        throw new NotFoundException('Withdrawal request not found');
      }

      if (withdrawal.status !== 'PENDING') {
        throw new BadRequestException('Withdrawal already processed');
      }

      const account = await tx.account.findUnique({
        where: { id: withdrawal.accountId },
      });

      if (!account) {
        throw new NotFoundException('Account not found');
      }
      if (role === 'FINANCE') await this.assertFinanceAccount(account.userId, tx);

      const amount = Number(withdrawal.amount);
      const withdrawalFrozenAmount = Number(withdrawal.frozenAmount);
      const hasDedicatedFreeze = withdrawalFrozenAmount >= amount;
      const cashBalance = Number(account.cashBalance);
      const frozenBalance = Number(account.frozenBalance);
      const buyingPower = Number(account.buyingPower);

      if (cashBalance < amount) {
        throw new BadRequestException('Insufficient cash balance');
      }
      if (hasDedicatedFreeze && frozenBalance < amount) {
        throw new BadRequestException(
          'Frozen balance is inconsistent with withdrawal request',
        );
      }

      const balanceAfter = cashBalance - amount;
      const frozenBalanceAfter = hasDedicatedFreeze
        ? frozenBalance - amount
        : frozenBalance;

      const claimed = await tx.withdrawalRequest.updateMany({
        where: { id: withdrawalId, status: 'PENDING' },
        data: { status: 'APPROVED', frozenAmount: 0 },
      });
      if (claimed.count !== 1) {
        throw new BadRequestException('Withdrawal already processed');
      }

      await tx.account.update({
        where: { id: account.id },
        data: {
          cashBalance: balanceAfter,
          ...(hasDedicatedFreeze
            ? { frozenBalance: { decrement: amount } }
            : { buyingPower: Math.max(0, buyingPower - amount) }),
        },
      });

      await tx.accountTransaction.create({
        data: {
          accountId: account.id,
          type: 'WITHDRAWAL',
          status: 'COMPLETED',
          amount: withdrawal.amount,
          balanceBefore: cashBalance,
          balanceAfter,
          referenceId: withdrawalId,
          note: 'Withdrawal approved',
        },
      });
      await tx.notification.create({
        data: {
          userId: account.userId,
          type: 'WITHDRAWAL',
          title: 'Withdrawal approved',
          body: `${withdrawal.orderNo ?? 'Your withdrawal'} has been completed and deducted from your cash balance.`,
          referenceId: withdrawalId,
        },
      });

      return {
        message: 'Withdrawal approved',
        withdrawalId,
        amount: withdrawal.amount,
        balanceBefore: cashBalance,
        balanceAfter,
        frozenBalanceAfter,
      };
    });
    if (actorId) await this.audit.createLog({ actorId, action: 'WITHDRAWAL_APPROVED', resource: 'withdrawal', resourceId: withdrawalId, description: 'Withdrawal approved by finance operator', metadata: { amount: String(result.amount) } });
    return result;
  }

  async rejectWithdrawal(withdrawalId: string, note?: string, actorId?: string, role?: string) {
    const rejected = await this.prisma.$transaction(async (tx) => {
      const withdrawal = await tx.withdrawalRequest.findUnique({
        where: { id: withdrawalId },
      });
      if (!withdrawal) {
        throw new NotFoundException('Withdrawal request not found');
      }
      if (withdrawal.status !== 'PENDING') {
        throw new BadRequestException('Withdrawal already processed');
      }

      const account = await tx.account.findUnique({
        where: { id: withdrawal.accountId },
      });
      if (!account) {
        throw new NotFoundException('Account not found');
      }
      if (role === 'FINANCE') await this.assertFinanceAccount(account.userId, tx);
      const amount = Number(withdrawal.amount);
      const hasDedicatedFreeze = Number(withdrawal.frozenAmount) >= amount;
      if (hasDedicatedFreeze && Number(account.frozenBalance) < amount) {
        throw new BadRequestException(
          'Frozen balance is inconsistent with withdrawal request',
        );
      }

      const claimed = await tx.withdrawalRequest.updateMany({
        where: { id: withdrawalId, status: 'PENDING' },
        data: {
          status: 'REJECTED',
          frozenAmount: 0,
          note: note?.trim() || withdrawal.note,
        },
      });
      if (claimed.count !== 1) {
        throw new BadRequestException('Withdrawal already processed');
      }
      if (hasDedicatedFreeze) {
        await tx.account.update({
          where: { id: account.id },
          data: {
            buyingPower: { increment: amount },
            frozenBalance: { decrement: amount },
          },
        });
      }
      await tx.notification.create({
        data: {
          userId: account.userId,
          type: 'WITHDRAWAL',
          title: 'Withdrawal rejected',
          body: `${withdrawal.orderNo ?? 'Your withdrawal'} was rejected and the frozen funds were released.${note ? ` ${note}` : ''}`,
          referenceId: withdrawalId,
        },
      });
      return tx.withdrawalRequest.findUnique({
        where: { id: withdrawalId },
      });
    });
    if (actorId) await this.audit.createLog({ actorId, action: 'WITHDRAWAL_REJECTED', resource: 'withdrawal', resourceId: withdrawalId, description: note?.trim() || 'Withdrawal rejected by finance operator' });
    return rejected;
  }

  private async assertFinanceAccount(userId: string, tx: any) {
    const fixedCode = process.env.ADMIN_FIXED_INVITE_CODE?.trim().toUpperCase() || 'ADMINFIXED2026';
    const user = await tx.user.findUnique({ where: { id: userId }, select: { usedInviteCode: { select: { code: true } } } });
    if (user?.usedInviteCode?.code?.toUpperCase() === fixedCode) throw new NotFoundException('Withdrawal request not found');
  }

  private generateOrderNo() {
    const now = new Date();
    const date = [
      now.getFullYear(),
      String(now.getMonth() + 1).padStart(2, '0'),
      String(now.getDate()).padStart(2, '0'),
    ].join('');
    const suffix = randomBytes(5).toString('hex').slice(0, 8).toUpperCase();

    return `WD${date}${suffix}`;
  }
}
