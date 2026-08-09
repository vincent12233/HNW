import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class WithdrawalService {
  constructor(private readonly prisma: PrismaService) {}

  async createRequest(
    userId: string,
    amount: number,
    bankName?: string,
    accountNumber?: string,
    ifscCode?: string,
    upiId?: string,
    note?: string,
  ) {
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Amount must be greater than zero');
    }

    if (!upiId && (!bankName || !accountNumber || !ifscCode)) {
      throw new BadRequestException(
        'Provide either UPI ID or complete bank details',
      );
    }

    const account = await this.prisma.account.findUnique({
      where: { userId },
    });

    if (!account) {
      throw new NotFoundException('Account not found');
    }

    if (Number(account.cashBalance) < amount) {
      throw new BadRequestException('Insufficient cash balance');
    }

    return this.prisma.withdrawalRequest.create({
      data: {
        orderNo: this.generateOrderNo(),
        accountId: account.id,
        amount,
        bankName: bankName?.trim() || null,
        accountNumber: accountNumber?.trim() || null,
        ifscCode: ifscCode?.trim().toUpperCase() || null,
        upiId: upiId?.trim() || null,
        note: note?.trim() || null,
        status: 'PENDING',
      },
    });
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

  async listPendingWithdrawals() {
    return this.prisma.withdrawalRequest.findMany({
      where: { status: 'PENDING' },
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

  async approveWithdrawal(withdrawalId: string) {
    return this.prisma.$transaction(async (tx) => {
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

      const amount = Number(withdrawal.amount);
      const cashBalance = Number(account.cashBalance);
      const buyingPower = Number(account.buyingPower);

      if (cashBalance < amount) {
        throw new BadRequestException('Insufficient cash balance');
      }

      const balanceAfter = cashBalance - amount;
      const buyingPowerAfter = Math.max(0, buyingPower - amount);

      await tx.account.update({
        where: { id: account.id },
        data: {
          cashBalance: balanceAfter,
          buyingPower: buyingPowerAfter,
        },
      });

      await tx.withdrawalRequest.update({
        where: { id: withdrawalId },
        data: { status: 'APPROVED' },
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

      return {
        message: 'Withdrawal approved',
        withdrawalId,
        amount: withdrawal.amount,
        balanceBefore: cashBalance,
        balanceAfter,
        buyingPowerAfter,
      };
    });
  }

  async rejectWithdrawal(withdrawalId: string, note?: string) {
    const withdrawal = await this.prisma.withdrawalRequest.findUnique({
      where: { id: withdrawalId },
    });

    if (!withdrawal) {
      throw new NotFoundException('Withdrawal request not found');
    }

    if (withdrawal.status !== 'PENDING') {
      throw new BadRequestException('Withdrawal already processed');
    }

    return this.prisma.withdrawalRequest.update({
      where: { id: withdrawalId },
      data: {
        status: 'REJECTED',
        note: note?.trim() || withdrawal.note,
      },
    });
  }

  private generateOrderNo() {
    const now = new Date();
    const date = [
      now.getFullYear(),
      String(now.getMonth() + 1).padStart(2, '0'),
      String(now.getDate()).padStart(2, '0'),
    ].join('');
    const suffix = Math.random().toString(36).slice(2, 8).toUpperCase();

    return `WD${date}${suffix}`;
  }
}
