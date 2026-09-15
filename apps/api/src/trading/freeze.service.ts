import {
  BadRequestException,
  ConflictException,
  Injectable,
} from '@nestjs/common';
import { availableCash } from '../common/money';
import { Prisma } from '../generated/prisma/client';

@Injectable()
export class FreezeService {
  async freezeBuy(
    tx: Prisma.TransactionClient,
    accountId: string,
    cashBalance: Prisma.Decimal,
    amount: Prisma.Decimal,
    orderId: string,
    note: string,
  ) {
    const account = await tx.account.findUnique({ where: { id: accountId } });
    if (!account) throw new BadRequestException('Trading account not found');

    if (
      account.buyingPower.lessThan(amount) ||
      availableCash(account).lessThan(amount)
    ) {
      throw new BadRequestException(
        'Insufficient buying power or cash balance',
      );
    }

    await tx.account.update({
      where: { id: accountId },
      data: {
        buyingPower: { decrement: amount },
        frozenBalance: { increment: amount },
      },
    });

    await tx.accountTransaction.create({
      data: {
        accountId,
        type: 'ORDER_FREEZE',
        status: 'COMPLETED',
        amount: amount.negated(),
        balanceBefore: cashBalance,
        balanceAfter: cashBalance,
        referenceId: `ORDER:${orderId}:FREEZE`,
        note,
      },
    });
  }

  async freezeSell(
    tx: Prisma.TransactionClient,
    positionId: string,
    quantity: number,
  ) {
    const position = await tx.position.findUnique({
      where: { id: positionId },
    });
    if (!position) throw new BadRequestException('Position not found');

    const availableQuantity = position.quantity - position.frozenQuantity;
    if (availableQuantity < quantity) {
      throw new BadRequestException('Insufficient available position');
    }

    await tx.position.update({
      where: { id: positionId },
      data: { frozenQuantity: { increment: quantity } },
    });
  }

  async releaseBuy(
    tx: Prisma.TransactionClient,
    accountId: string,
    cashBalance: Prisma.Decimal,
    amount: Prisma.Decimal,
    orderId: string,
    note: string,
  ) {
    if (amount.lessThanOrEqualTo(0)) {
      throw new ConflictException('BUY order has no frozen amount to release');
    }

    const account = await tx.account.findUnique({ where: { id: accountId } });
    if (!account) {
      throw new ConflictException('Trading account no longer exists');
    }

    if (account.frozenBalance.lessThan(amount)) {
      throw new ConflictException(
        'Account frozen balance is inconsistent with the order',
      );
    }

    await tx.account.update({
      where: { id: accountId },
      data: {
        buyingPower: { increment: amount },
        frozenBalance: { decrement: amount },
      },
    });

    await tx.accountTransaction.create({
      data: {
        accountId,
        type: 'ORDER_RELEASE',
        status: 'COMPLETED',
        amount,
        balanceBefore: cashBalance,
        balanceAfter: cashBalance,
        referenceId: `ORDER:${orderId}:RELEASE`,
        note,
      },
    });
  }

  async releaseSell(
    tx: Prisma.TransactionClient,
    positionId: string,
    quantity: number,
  ) {
    if (quantity <= 0) {
      throw new ConflictException(
        'SELL order has no frozen quantity to release',
      );
    }

    const position = await tx.position.findUnique({
      where: { id: positionId },
    });
    if (!position) {
      throw new ConflictException(
        'Position for this SELL order no longer exists',
      );
    }

    if (position.frozenQuantity < quantity) {
      throw new ConflictException(
        'Frozen position quantity is inconsistent with the order',
      );
    }

    await tx.position.update({
      where: { id: positionId },
      data: { frozenQuantity: { decrement: quantity } },
    });
  }
}
