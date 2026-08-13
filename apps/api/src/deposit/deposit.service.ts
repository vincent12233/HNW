import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';

@Injectable()
export class DepositService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService) {}

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

  async approveDeposit(depositId: string, actorId?: string) {
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
      include: {
        ipoApplication: {
          include: {
            ipo: true,
          },
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

        if (payment >= remainingDebt) {
          await tx.ipoApplication.update({
            where: {
              id: debt.ipoApplicationId,
            },
            data: {
              paymentStatus: 'PAID',
            },
          });

          if (debt.ipoApplication.ipo.instrumentId) {
            await this.settleIpoApplication(tx, {
              applicationId: debt.ipoApplication.id,
              accountId: deposit.accountId,
              instrumentId: debt.ipoApplication.ipo.instrumentId,
              quantity: debt.ipoApplication.allocatedQuantity ?? 0,
              price: Number(
                debt.ipoApplication.allocatedPrice ??
                  debt.ipoApplication.ipo.issuePrice,
              ),
              totalAmount: Number(
                debt.ipoApplication.allocatedAmount ?? debt.amount,
              ),
            });
          }
        }

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

    const result = {
      message: 'Deposit approved',

      depositId,

      depositAmount: deposit.amount,

      ipoRepayment: repayAmount,

      creditedAmount: availableAmount,
    };
    if (actorId) await this.audit.createLog({ actorId, action: 'DEPOSIT_APPROVED', resource: 'deposit', resourceId: depositId, description: 'Deposit approved by finance operator', metadata: { depositAmount: String(deposit.amount), ipoRepayment: String(repayAmount), creditedAmount: String(availableAmount) } });
    return result;
  }

  async rejectDeposit(depositId: string, note?: string, actorId?: string) {
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

    if (actorId) await this.audit.createLog({ actorId, action: 'DEPOSIT_REJECTED', resource: 'deposit', resourceId: depositId, description: note?.trim() || 'Deposit rejected by finance operator' });
    return {
      message: 'Deposit rejected',
      depositId,
    };
  }

  private async settleIpoApplication(
    tx: any,
    input: {
      applicationId: string;
      accountId: string;
      instrumentId: string;
      quantity: number;
      price: number;
      totalAmount: number;
    },
  ) {
    if (input.quantity <= 0) {
      return;
    }

    const existingOrder = await tx.order.findUnique({
      where: {
        accountId_clientOrderId: {
          accountId: input.accountId,
          clientOrderId: `IPO-${input.applicationId}`,
        },
      },
    });

    if (existingOrder) {
      return;
    }

    const order = await tx.order.create({
      data: {
        clientOrderId: `IPO-${input.applicationId}`,
        accountId: input.accountId,
        instrumentId: input.instrumentId,
        side: 'BUY',
        type: 'MARKET',
        status: 'FILLED',
        quantity: input.quantity,
        filledQuantity: input.quantity,
        limitPrice: input.price,
        averageFillPrice: input.price,
        completedAt: new Date(),
      },
    });

    await tx.trade.create({
      data: {
        executionId: `IPO-EXEC-${input.applicationId}`,
        orderId: order.id,
        accountId: input.accountId,
        instrumentId: input.instrumentId,
        quantity: input.quantity,
        price: input.price,
        grossAmount: input.totalAmount,
        fees: 0,
        netAmount: input.totalAmount,
      },
    });

    const position = await tx.position.findUnique({
      where: {
        accountId_instrumentId: {
          accountId: input.accountId,
          instrumentId: input.instrumentId,
        },
      },
    });

    if (position) {
      const oldQty = position.quantity;
      const newQty = oldQty + input.quantity;
      const avgPrice =
        (Number(position.averagePrice) * oldQty +
          input.price * input.quantity) /
        newQty;

      await tx.position.update({
        where: {
          id: position.id,
        },
        data: {
          quantity: newQty,
          averagePrice: avgPrice,
        },
      });
    } else {
      await tx.position.create({
        data: {
          accountId: input.accountId,
          instrumentId: input.instrumentId,
          quantity: input.quantity,
          averagePrice: input.price,
        },
      });
    }
  }
}
