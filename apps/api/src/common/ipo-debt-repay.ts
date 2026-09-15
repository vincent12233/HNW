import { Prisma } from '../generated/prisma/client';
import { moneyDecimal } from './money';

export type SettleIpoInput = {
  applicationId: string;
  accountId: string;
  instrumentId: string;
  quantity: number;
  price: Prisma.Decimal | number;
  totalAmount: Prisma.Decimal | number;
};

/** Create filled IPO order/trade and upsert holdings (idempotent by clientOrderId). */
export async function settleIpoHoldings(
  tx: Prisma.TransactionClient,
  input: SettleIpoInput,
) {
  if (input.quantity <= 0) return;
  const price = moneyDecimal(input.price);
  const totalAmount = moneyDecimal(input.totalAmount);

  const existingOrder = await tx.order.findUnique({
    where: {
      accountId_clientOrderId: {
        accountId: input.accountId,
        clientOrderId: `IPO-${input.applicationId}`,
      },
    },
  });
  if (existingOrder) return existingOrder;

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
      limitPrice: price,
      averageFillPrice: price,
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
      price,
      grossAmount: totalAmount,
      fees: 0,
      netAmount: totalAmount,
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
    const avgPrice = new Prisma.Decimal(position.averagePrice)
      .mul(oldQty)
      .add(price.mul(input.quantity))
      .div(newQty)
      .toDecimalPlaces(4, Prisma.Decimal.ROUND_HALF_UP);
    await tx.position.update({
      where: { id: position.id },
      data: { quantity: newQty, averagePrice: avgPrice },
    });
  } else {
    await tx.position.create({
      data: {
        accountId: input.accountId,
        instrumentId: input.instrumentId,
        quantity: input.quantity,
        averagePrice: price,
      },
    });
  }
}

/**
 * Apply incoming funds to open/partial IPO debts (FIFO), then return surplus.
 * Repayments do not increase cash; full pay settles holdings via settleFn.
 */
export async function applyIncomingFundsToIpoDebts(
  tx: Prisma.TransactionClient,
  input: {
    accountId: string;
    userId: string;
    amount: Prisma.Decimal;
    balanceBefore: Prisma.Decimal;
  },
  settleFn: (
    tx: Prisma.TransactionClient,
    settle: SettleIpoInput,
  ) => Promise<unknown> = settleIpoHoldings,
): Promise<{ repayAmount: Prisma.Decimal; remainingAmount: Prisma.Decimal }> {
  let availableAmount = moneyDecimal(input.amount);
  let repayAmount = new Prisma.Decimal(0);

  const debts = await tx.ipoDebt.findMany({
    where: {
      accountId: input.accountId,
      status: { in: ['OPEN', 'PARTIAL'] },
    },
    include: { ipoApplication: { include: { ipo: true } } },
    orderBy: { createdAt: 'asc' },
  });

  for (const debt of debts) {
    if (availableAmount.lte(0)) break;

    const remainingDebt = moneyDecimal(debt.amount).sub(
      moneyDecimal(debt.paidAmount),
    );
    if (remainingDebt.lte(0)) continue;

    const payment = availableAmount.lt(remainingDebt)
      ? availableAmount
      : remainingDebt;

    await tx.ipoDebt.update({
      where: { id: debt.id },
      data: {
        paidAmount: { increment: payment },
        status: payment.gte(remainingDebt) ? 'PAID' : 'PARTIAL',
      },
    });

    if (payment.gte(remainingDebt)) {
      await tx.ipoApplication.update({
        where: { id: debt.ipoApplicationId },
        data: { paymentStatus: 'PAID' },
      });

      if (debt.ipoApplication.ipo.instrumentId) {
        await settleFn(tx, {
          applicationId: debt.ipoApplication.id,
          accountId: input.accountId,
          instrumentId: debt.ipoApplication.ipo.instrumentId,
          quantity: debt.ipoApplication.allocatedQuantity ?? 0,
          price:
            debt.ipoApplication.allocatedPrice ??
            debt.ipoApplication.ipo.issuePrice,
          totalAmount: debt.ipoApplication.allocatedAmount ?? debt.amount,
        });
        await tx.notification.create({
          data: {
            userId: input.userId,
            type: 'IPO_ALLOTMENT_SETTLED',
            title: 'IPO payment completed',
            body: `${debt.ipoApplication.ipo.symbol} is fully paid and has been added to your holdings.`,
            referenceId: debt.ipoApplication.id,
          },
        });
      }
    }

    await tx.accountTransaction.create({
      data: {
        accountId: input.accountId,
        type: 'IPO_REPAYMENT',
        status: 'COMPLETED',
        amount: payment,
        balanceBefore: input.balanceBefore,
        balanceAfter: input.balanceBefore,
        referenceId: debt.id,
        note: 'IPO debt repayment',
      },
    });

    availableAmount = availableAmount.sub(payment);
    repayAmount = repayAmount.add(payment);
  }

  return { repayAmount, remainingAmount: availableAmount };
}
