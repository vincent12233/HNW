import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { applyIncomingFundsToIpoDebts, settleIpoHoldings, SettleIpoInput } from '../common/ipo-debt-repay';
import { fixedInviteCode } from '../common/fixed-invite';
import { moneyDecimal } from '../common/money';

@Injectable()
export class DepositService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService) {}

  async submitToFinanceBySupport(
    supportUserId: string,
    input: { conversationId?: string; amount?: string; referenceId?: string; paymentMethod?: string; note?: string },
  ) {
    const conversationId = String(input.conversationId ?? '').trim();
    const referenceId = String(input.referenceId ?? '').trim().toUpperCase();
    const amountText = String(input.amount ?? '').trim();
    if (!conversationId) throw new BadRequestException('Support conversation is required');
    if (!/^(?!0+(?:\.0{1,2})?$)\d+(?:\.\d{1,2})?$/.test(amountText)) {
      throw new BadRequestException('Enter a positive deposit amount with up to 2 decimals');
    }
    if (!/^[A-Z0-9._:-]{8,100}$/.test(referenceId)) {
      throw new BadRequestException('Enter a valid payment reference');
    }
    const amount = new Prisma.Decimal(amountText);
    const deposit = await this.prisma.$transaction(async (tx) => {
      const conversation = await tx.supportConversation.findUnique({
        where: { id: conversationId },
        select: { clientId: true, assignedToId: true },
      });
      if (!conversation) throw new NotFoundException('Support conversation not found');
      if (conversation.assignedToId !== supportUserId) {
        throw new BadRequestException('This conversation is not assigned to the current dedicated operator');
      }
      const fixedCode = fixedInviteCode();
      const customer = await tx.user.findFirst({
        where: { id: conversation.clientId, role: 'CLIENT', assignedBusinessId: supportUserId, usedInviteCode: { is: { code: fixedCode } } },
        select: { id: true },
      });
      if (!customer) {
        throw new BadRequestException('This customer is outside the dedicated operator scope');
      }
      const account = await tx.account.findUnique({ where: { userId: conversation.clientId } });
      if (!account) throw new NotFoundException('Customer account not found');
      const duplicate = await tx.depositRequest.findUnique({ where: { referenceId } });
      if (duplicate) throw new BadRequestException('This payment reference has already been confirmed');
      const created = await tx.depositRequest.create({
        data: {
          accountId: account.id,
          amount,
          referenceId,
          paymentMethod: String(input.paymentMethod ?? '').trim().slice(0, 80) || null,
          note: [String(input.note ?? '').trim(), `Submitted by support ${supportUserId}`].filter(Boolean).join(' | ').slice(0, 500),
          status: 'PENDING',
        },
      });
      await tx.notification.create({
        data: {
          userId: conversation.clientId,
          type: 'DEPOSIT',
          title: 'Deposit details submitted',
          body: `Your deposit details for ${amount.toFixed(2)} were sent to finance for independent receipt verification.`,
          referenceId: created.id,
        },
      });
      return created;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    await this.audit.createLog({
      actorId: supportUserId,
      action: 'DEPOSIT_DETAILS_SUBMITTED',
      resource: 'deposit',
      resourceId: deposit.id,
      description: 'Deposit details submitted by support for finance verification',
      metadata: { referenceId, amount: amount.toFixed(2), conversationId },
    });
    return deposit;
  }

  async createDepositRequest(
    _userId: string,
    _amount: number,
    _paymentMethod?: string,
    _note?: string,
  ) {
    // Client self-serve deposit creation stays disabled; funding is support-led.
    throw new BadRequestException(
      'Client deposit submission is disabled; contact support to fund your account',
    );
  }

  async myDeposits(userId: string) {
    const account = await this.prisma.account.findUnique({
      where: {
        userId,
      },
    });

    if (!account) {
      throw new NotFoundException('Account not found');
    }

    return this.prisma.depositRequest.findMany({
      where: {
        accountId: account.id,
      },

      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  // 客服查看待审核充值
  async listPendingDeposits(role: string, actorId?: string) {
    return this.prisma.depositRequest.findMany({
      where: {
        status: 'PENDING',
        account: { user: this.depositCustomerScope(role, actorId) },
      },

      include: {
        account: {
          select: {
            id: true,
            accountNumber: true,
            currency: true,
            user: {
              select: {
                id: true,
                customerNo: true,
                fullName: true,
                phone: true,
                status: true,
              },
            },
          },
        },
      },

      orderBy: {
        createdAt: 'asc',
      },
    });
  }

  async listDepositHistory(role: string, actorId?: string, status?: string) {
    const normalized = String(status ?? 'ALL').trim().toUpperCase();
    const allowed = new Set(['ALL', 'PENDING', 'APPROVED', 'REJECTED']);
    if (!allowed.has(normalized)) {
      throw new BadRequestException('Invalid deposit status filter');
    }

    return this.prisma.depositRequest.findMany({
      where: {
        ...(normalized === 'ALL' ? {} : { status: normalized as 'PENDING' | 'APPROVED' | 'REJECTED' }),
        account: { user: this.depositCustomerScope(role, actorId) },
      },
      include: {
        account: {
          select: {
            id: true,
            accountNumber: true,
            currency: true,
            user: {
              select: {
                id: true,
                customerNo: true,
                fullName: true,
                phone: true,
                status: true,
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 200,
    });
  }

  async approveDeposit(depositId: string, actorId: string, role: string) {
    const deposit = await this.prisma.depositRequest.findUnique({
      where: {
        id: depositId,
      },

      include: {
        account: true,
      },
    });

    if (!deposit) {
      throw new NotFoundException('Deposit request not found');
    }

    if (deposit.status !== 'PENDING') {
      throw new BadRequestException('Deposit already processed');
    }

    let repayAmount = new Prisma.Decimal(0);

    let availableAmount = moneyDecimal(deposit.amount);

    await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.depositRequest.updateMany({
        where: { id: depositId, status: 'PENDING' },
        data: { status: 'APPROVED' },
      });
      if (claimed.count !== 1) {
        throw new BadRequestException('Deposit already processed');
      }
      const account = await tx.account.findUnique({
        where: {
          id: deposit.accountId,
        },
      });

      if (!account) {
        throw new NotFoundException('Account not found');
      }
      await this.assertDepositVisible(account.userId, role, actorId, tx);

      const balanceBefore = moneyDecimal(account.cashBalance);
      const { repayAmount: applied, remainingAmount } =
        await applyIncomingFundsToIpoDebts(
          tx,
          {
            accountId: deposit.accountId,
            userId: account.userId,
            amount: availableAmount,
            balanceBefore,
          },
          (client, settle) => this.settleIpoApplication(client, settle),
        );
      repayAmount = applied;
      availableAmount = remainingAmount;

      /*
          2.
          Deposit 状态更新
        */

      /*
          3.
          Deposit 流水
        */

      /*
          4.
          剩余资金进入账户
        */

      if (availableAmount.gt(0)) {
        await tx.account.update({
          where: {
            id: deposit.accountId,
          },

          data: {
            cashBalance: {
              increment: availableAmount,
            },

            buyingPower: {
              increment: availableAmount,
            },
          },
        });

      }
      await tx.accountTransaction.create({
        data: {
          accountId: deposit.accountId,
          type: 'DEPOSIT',
          status: 'COMPLETED',
          amount: availableAmount,
          balanceBefore,
          balanceAfter: balanceBefore.add(availableAmount),
          referenceId: depositId,
          note: repayAmount.gt(0)
            ? `Deposit approved; ${repayAmount.toFixed(2)} applied to IPO debt`
            : 'Deposit approved',
        },
      });
      await tx.notification.create({
        data: {
          userId: account.userId,
          type: 'DEPOSIT',
          title: 'Deposit approved',
          body: repayAmount.gt(0)
            ? availableAmount.gt(0)
              ? `${availableAmount.toFixed(2)} added to available balance; ${repayAmount.toFixed(2)} applied to IPO debt.`
              : `${repayAmount.toFixed(2)} applied to IPO debt; no surplus credited to cash.`
            : `${availableAmount.toFixed(2)} has been added to your available balance.`,
          referenceId: depositId,
        },
      });
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });

    const result = {
      message: 'Deposit approved',

      depositId,

      depositAmount: deposit.amount,

      ipoRepayment: repayAmount,

      creditedAmount: availableAmount,
    };
    if (actorId) await this.audit.createLog({ actorId, action: 'DEPOSIT_APPROVED', resource: 'deposit', resourceId: depositId, description: 'Deposit approved by finance operator', metadata: { depositAmount: String(deposit.amount), ipoRepayment: repayAmount.toFixed(2), creditedAmount: availableAmount.toFixed(2) } });
    return result;
  }

  async rejectDeposit(depositId: string, note: string | undefined, actorId: string, role: string) {
    await this.prisma.$transaction(async (tx) => {
      const deposit = await tx.depositRequest.findUnique({
        where: { id: depositId },
        include: { account: true },
      });
      if (!deposit) throw new NotFoundException('Deposit request not found');
      await this.assertDepositVisible(deposit.account.userId, role, actorId, tx);
      const updated = await tx.depositRequest.updateMany({
        where: { id: depositId, status: 'PENDING' },
        data: { status: 'REJECTED', note: note?.trim() || null },
      });
      if (updated.count !== 1) {
        throw new BadRequestException('Deposit already processed');
      }
      await tx.notification.create({
        data: {
          userId: deposit.account.userId,
          type: 'DEPOSIT',
          title: 'Deposit rejected',
          body: note?.trim() || 'Your deposit could not be confirmed. Please contact support.',
          referenceId: depositId,
        },
      });
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });

    if (actorId) await this.audit.createLog({ actorId, action: 'DEPOSIT_REJECTED', resource: 'deposit', resourceId: depositId, description: note?.trim() || 'Deposit rejected by finance operator' });
    return {
      message: 'Deposit rejected',
      depositId,
    };
  }

  private depositCustomerScope(role: string, actorId?: string): Prisma.UserWhereInput {
    const fixedCode = fixedInviteCode();
    if (role === 'SUPPORT') {
      return { assignedBusinessId: actorId, usedInviteCode: { is: { code: fixedCode } } };
    }
    if (role !== 'FINANCE') return {};
    return { NOT: { usedInviteCode: { is: { code: fixedCode } } } };
  }

  private async assertDepositVisible(userId: string, role: string, actorId: string, tx: any) {
    const visible = await tx.user.count({ where: { id: userId, ...this.depositCustomerScope(role, actorId) } });
    if (!visible) throw new NotFoundException('Deposit request not found');
  }

  private async settleIpoApplication(tx: any, input: SettleIpoInput) {
    return settleIpoHoldings(tx, input);
  }
}
