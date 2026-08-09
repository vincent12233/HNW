import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DepositService {
  constructor(private readonly prisma: PrismaService) {}

  async createDepositRequest(
    userId: string,
    amount: number,
    paymentMethod?: string,
    note?: string,
  ) {
    const account = await this.prisma.account.findUnique({
      where: {
        userId,
      },
    });

    if (!account) {
      throw new NotFoundException('Account not found');
    }

    return this.prisma.depositRequest.create({
      data: {
        accountId: account.id,

        amount,

        paymentMethod,

        note,

        status: 'PENDING',
      },
    });
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
  async listPendingDeposits() {
    return this.prisma.depositRequest.findMany({
      where: {
        status: 'PENDING',
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

  async approveDeposit(depositId: string) {
    const deposit = await this.prisma.depositRequest.findUnique({
      where: {
        id: depositId,
      },

      include: {
        account: true,
      },
    });

    if (!deposit) {
      throw new Error('Deposit request not found');
    }

    if (deposit.status !== 'PENDING') {
      throw new Error('Deposit already processed');
    }

    const debts = await this.prisma.ipoDebt.findMany({
      where: {
        accountId: deposit.accountId,

        status: {
          in: ['OPEN', 'PARTIAL'],
        },
      },

      orderBy: {
        createdAt: 'asc',
      },
    });

    let repayAmount = 0;

    let availableAmount = Number(deposit.amount);

    await this.prisma.$transaction(async (tx) => {
      const account = await tx.account.findUnique({
        where: {
          id: deposit.accountId,
        },
      });

      if (!account) {
        throw new Error('Account not found');
      }

      const balanceBefore = Number(account.cashBalance);

      /*
          1.
          自动偿还 IPO Debt
        */

      for (const debt of debts) {
        if (availableAmount <= 0) {
          break;
        }

        const remainingDebt = Number(debt.amount) - Number(debt.paidAmount);

        const payment = Math.min(availableAmount, remainingDebt);

        await tx.ipoDebt.update({
          where: {
            id: debt.id,
          },

          data: {
            paidAmount: {
              increment: payment,
            },

            status: payment >= remainingDebt ? 'PAID' : 'PARTIAL',
          },
        });

        await tx.accountTransaction.create({
          data: {
            accountId: deposit.accountId,

            type: 'IPO_REPAYMENT',

            status: 'COMPLETED',

            amount: payment,

            balanceBefore,

            balanceAfter: balanceBefore,

            referenceId: debt.id,

            note: 'IPO debt repayment',
          },
        });

        availableAmount -= payment;

        repayAmount += payment;
      }

      /*
          2.
          Deposit 状态更新
        */

      await tx.depositRequest.update({
        where: {
          id: depositId,
        },

        data: {
          status: 'APPROVED',
        },
      });

      /*
          3.
          Deposit 流水
        */

      await tx.accountTransaction.create({
        data: {
          accountId: deposit.accountId,

          type: 'DEPOSIT',

          status: 'COMPLETED',

          amount: deposit.amount,

          balanceBefore,

          balanceAfter: balanceBefore + Number(deposit.amount),

          referenceId: depositId,

          note: 'Deposit approved',
        },
      });

      /*
          4.
          剩余资金进入账户
        */

      if (availableAmount > 0) {
        const balanceAfter = balanceBefore + availableAmount;

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

        await tx.accountTransaction.create({
          data: {
            accountId: deposit.accountId,

            type: 'ADMIN_CREDIT',

            status: 'COMPLETED',

            amount: availableAmount,

            balanceBefore,

            balanceAfter,

            referenceId: depositId,

            note: 'Deposit cash credit',
          },
        });
      }
    });

    return {
      message: 'Deposit approved',

      depositId,

      depositAmount: deposit.amount,

      ipoRepayment: repayAmount,

      creditedAmount: availableAmount,
    };
  }

  async rejectDeposit(depositId: string, note?: string) {
    const updated = await this.prisma.depositRequest.updateMany({
      where: {
        id: depositId,
        status: 'PENDING',
      },
      data: {
        status: 'REJECTED',
        note: note?.trim() || null,
      },
    });

    if (updated.count !== 1) {
      throw new NotFoundException('Pending deposit request not found');
    }

    return {
      message: 'Deposit rejected',
      depositId,
    };
  }
}
