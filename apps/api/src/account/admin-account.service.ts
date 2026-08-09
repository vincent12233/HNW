import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditService } from '../audit/audit.service';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AdjustBalanceDto } from './dto/adjust-balance.dto';
import { ListAdminAccountsQueryDto } from './dto/list-admin-accounts-query.dto';
import { ListAdminAccountTransactionsQueryDto } from './dto/list-admin-account-transactions-query.dto';
type AdjustmentDirection = 'CREDIT' | 'DEBIT';

@Injectable()
export class AdminAccountService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}
  credit(
    accountNumber: string,
    dto: AdjustBalanceDto,
    administratorId: string,
  ) {
    return this.adjust(accountNumber, dto, administratorId, 'CREDIT');
  }

  debit(accountNumber: string, dto: AdjustBalanceDto, administratorId: string) {
    return this.adjust(accountNumber, dto, administratorId, 'DEBIT');
  }
  async listAccounts(query: ListAdminAccountsQueryDto) {
    const search = query.search?.trim();
    const skip = (query.page - 1) * query.pageSize;

    const where: Prisma.AccountWhereInput = search
      ? {
          OR: [
            {
              accountNumber: {
                contains: search,
                mode: 'insensitive',
              },
            },
            {
              user: {
                fullName: {
                  contains: search,
                  mode: 'insensitive',
                },
              },
            },
            {
              user: {
                phone: {
                  contains: search,
                  mode: 'insensitive',
                },
              },
            },
            {
              user: {
                customerNo: {
                  contains: search,
                  mode: 'insensitive',
                },
              },
            },
          ],
        }
      : {};

    const [total, accounts] = await this.prisma.$transaction([
      this.prisma.account.count({ where }),
      this.prisma.account.findMany({
        where,
        include: {
          user: {
            select: {
              id: true,
              customerNo: true,
              fullName: true,
              phone: true,
              role: true,
              status: true,
            },
          },
          positions: {
            where: {
              quantity: {
                gt: 0,
              },
            },
            include: {
              instrument: {
                include: {
                  quote: true,
                },
              },
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: query.pageSize,
      }),
    ]);

    const data = accounts.map((account) => {
      const holdingsMarketValue = account.positions.reduce(
        (totalValue, position) => {
          const lastPrice =
            position.instrument.quote?.lastPrice ?? new Prisma.Decimal(0);

          return totalValue.add(lastPrice.mul(position.quantity));
        },
        new Prisma.Decimal(0),
      );

      const totalAsset = account.cashBalance
        .add(holdingsMarketValue)
        .toDecimalPlaces(2);

      return {
        id: account.id,
        accountNumber: account.accountNumber,
        currency: account.currency,
        isSandbox: account.isSandbox,
        balances: {
          cashBalance: account.cashBalance.toFixed(2),
          buyingPower: account.buyingPower.toFixed(2),
          frozenBalance: account.frozenBalance.toFixed(2),
          holdingsMarketValue: holdingsMarketValue.toFixed(2),
          totalAsset: totalAsset.toFixed(2),
        },
        positionCount: account.positions.length,
        user: account.user,
        createdAt: account.createdAt,
        updatedAt: account.updatedAt,
      };
    });

    return {
      page: query.page,
      pageSize: query.pageSize,
      total,
      totalPages: Math.ceil(total / query.pageSize),
      search: search ?? null,
      data,
    };
  }
  async getAccount(accountNumber: string) {
    const normalizedAccountNumber = accountNumber.trim().toUpperCase();

    const account = await this.prisma.account.findUnique({
      where: {
        accountNumber: normalizedAccountNumber,
      },
      include: {
        user: {
          select: {
            id: true,
            customerNo: true,
            fullName: true,
            phone: true,
            role: true,
            status: true,
            createdAt: true,
          },
        },
        positions: {
          where: {
            quantity: {
              gt: 0,
            },
          },
          include: {
            instrument: {
              include: {
                quote: true,
              },
            },
          },
          orderBy: {
            updatedAt: 'desc',
          },
        },
      },
    });

    if (!account) {
      throw new NotFoundException('未找到账户');
    }

    let holdingsMarketValue = new Prisma.Decimal(0);
    let realizedPnl = new Prisma.Decimal(0);
    let unrealizedPnl = new Prisma.Decimal(0);

    const positions = account.positions.map((position) => {
      const lastPrice =
        position.instrument.quote?.lastPrice ?? new Prisma.Decimal(0);

      const marketValue = lastPrice.mul(position.quantity).toDecimalPlaces(2);

      const positionUnrealizedPnl = lastPrice
        .sub(position.averagePrice)
        .mul(position.quantity)
        .toDecimalPlaces(2);

      holdingsMarketValue = holdingsMarketValue.add(marketValue);
      realizedPnl = realizedPnl.add(position.realizedPnl);
      unrealizedPnl = unrealizedPnl.add(positionUnrealizedPnl);

      return {
        id: position.id,
        exchange: position.instrument.exchange,
        symbol: position.instrument.symbol,
        name: position.instrument.name,
        quantity: position.quantity,
        frozenQuantity: position.frozenQuantity,
        availableQuantity: position.quantity - position.frozenQuantity,
        averagePrice: position.averagePrice.toFixed(4),
        lastPrice: lastPrice.toFixed(4),
        marketValue: marketValue.toFixed(2),
        realizedPnl: position.realizedPnl.toFixed(2),
        unrealizedPnl: positionUnrealizedPnl.toFixed(2),
        updatedAt: position.updatedAt,
      };
    });

    const totalAsset = account.cashBalance
      .add(holdingsMarketValue)
      .toDecimalPlaces(2);

    return {
      id: account.id,
      accountNumber: account.accountNumber,
      currency: account.currency,
      isSandbox: account.isSandbox,
      user: account.user,
      balances: {
        cashBalance: account.cashBalance.toFixed(2),
        buyingPower: account.buyingPower.toFixed(2),
        frozenBalance: account.frozenBalance.toFixed(2),
        holdingsMarketValue: holdingsMarketValue.toFixed(2),
        totalAsset: totalAsset.toFixed(2),
      },
      pnl: {
        realizedPnl: realizedPnl.toFixed(2),
        unrealizedPnl: unrealizedPnl.toFixed(2),
        totalPnl: realizedPnl.add(unrealizedPnl).toFixed(2),
      },
      positionCount: positions.length,
      positions,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    };
  }
  async getAccountTransactions(
    accountNumber: string,
    query: ListAdminAccountTransactionsQueryDto,
  ) {
    const normalizedAccountNumber = accountNumber.trim().toUpperCase();

    const account = await this.prisma.account.findUnique({
      where: {
        accountNumber: normalizedAccountNumber,
      },
      select: {
        id: true,
        accountNumber: true,
        currency: true,
      },
    });

    if (!account) {
      throw new NotFoundException('未找到账户');
    }

    if (
      query.dateFrom &&
      query.dateTo &&
      new Date(query.dateFrom) > new Date(query.dateTo)
    ) {
      throw new BadRequestException(
        'dateFrom must be earlier than or equal to dateTo',
      );
    }

    const where: Prisma.AccountTransactionWhereInput = {
      accountId: account.id,
      ...(query.type ? { type: query.type } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.dateFrom || query.dateTo
        ? {
            createdAt: {
              ...(query.dateFrom ? { gte: new Date(query.dateFrom) } : {}),
              ...(query.dateTo ? { lte: new Date(query.dateTo) } : {}),
            },
          }
        : {}),
    };

    const skip = (query.page - 1) * query.pageSize;

    const [total, transactions] = await this.prisma.$transaction([
      this.prisma.accountTransaction.count({
        where,
      }),
      this.prisma.accountTransaction.findMany({
        where,
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: query.pageSize,
        select: {
          id: true,
          type: true,
          status: true,
          amount: true,
          balanceBefore: true,
          balanceAfter: true,
          referenceId: true,
          note: true,
          createdBy: {
            select: {
              id: true,
              fullName: true,
              phone: true,
              role: true,
            },
          },
          createdAt: true,
          updatedAt: true,
        },
      }),
    ]);

    return {
      accountNumber: account.accountNumber,
      currency: account.currency,
      filters: {
        type: query.type ?? null,
        status: query.status ?? null,
        dateFrom: query.dateFrom ?? null,
        dateTo: query.dateTo ?? null,
      },
      data: transactions.map((transaction) => ({
        ...transaction,
        amount: transaction.amount.toFixed(2),
        balanceBefore: transaction.balanceBefore.toFixed(2),
        balanceAfter: transaction.balanceAfter.toFixed(2),
      })),
      pagination: {
        page: query.page,
        pageSize: query.pageSize,
        total,
        totalPages: Math.ceil(total / query.pageSize),
      },
    };
  }

  async listTransactions(query: ListAdminAccountTransactionsQueryDto) {
    if (
      query.dateFrom &&
      query.dateTo &&
      new Date(query.dateFrom) > new Date(query.dateTo)
    ) {
      throw new BadRequestException(
        'dateFrom must be earlier than or equal to dateTo',
      );
    }

    const where: Prisma.AccountTransactionWhereInput = {
      ...(query.type ? { type: query.type } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.dateFrom || query.dateTo
        ? {
            createdAt: {
              ...(query.dateFrom ? { gte: new Date(query.dateFrom) } : {}),
              ...(query.dateTo ? { lte: new Date(query.dateTo) } : {}),
            },
          }
        : {}),
    };
    const skip = (query.page - 1) * query.pageSize;

    const [total, transactions] = await this.prisma.$transaction([
      this.prisma.accountTransaction.count({ where }),
      this.prisma.accountTransaction.findMany({
        where,
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: query.pageSize,
        select: {
          id: true,
          type: true,
          status: true,
          amount: true,
          balanceBefore: true,
          balanceAfter: true,
          referenceId: true,
          note: true,
          account: {
            select: {
              accountNumber: true,
              currency: true,
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
          createdBy: {
            select: {
              id: true,
              fullName: true,
              phone: true,
              role: true,
            },
          },
          createdAt: true,
          updatedAt: true,
        },
      }),
    ]);

    return {
      filters: {
        type: query.type ?? null,
        status: query.status ?? null,
        dateFrom: query.dateFrom ?? null,
        dateTo: query.dateTo ?? null,
      },
      data: transactions.map((transaction) => ({
        ...transaction,
        amount: transaction.amount.toFixed(2),
        balanceBefore: transaction.balanceBefore.toFixed(2),
        balanceAfter: transaction.balanceAfter.toFixed(2),
      })),
      pagination: {
        page: query.page,
        pageSize: query.pageSize,
        total,
        totalPages: Math.ceil(total / query.pageSize),
      },
    };
  }

  private async adjust(
    accountNumber: string,
    dto: AdjustBalanceDto,
    administratorId: string,
    direction: AdjustmentDirection,
  ) {
    const normalizedAccountNumber = accountNumber.trim().toUpperCase();
    const referenceId = dto.referenceId.trim();
    const amount = new Prisma.Decimal(dto.amount);

    let attempt = 0;

    while (attempt < 3) {
      attempt += 1;

      try {
        const operation = await this.prisma.$transaction(
          async (tx) => {
            const duplicate = await tx.accountTransaction.findFirst({
              where: { referenceId },
              select: { id: true },
            });

            if (duplicate) {
              throw new ConflictException('该付款流水号已处理');
            }

            const account = await tx.account.findUnique({
              where: {
                accountNumber: normalizedAccountNumber,
              },
            });

            if (!account) {
              throw new NotFoundException('未找到账户');
            }

            if (
              direction === 'DEBIT' &&
              (account.cashBalance.lt(amount) || account.buyingPower.lt(amount))
            ) {
              throw new BadRequestException('可用余额不足');
            }

            const balanceBefore = account.cashBalance;

            const updatedAccount = await tx.account.update({
              where: { id: account.id },
              data:
                direction === 'CREDIT'
                  ? {
                      cashBalance: { increment: amount },
                      buyingPower: { increment: amount },
                    }
                  : {
                      cashBalance: { decrement: amount },
                      buyingPower: { decrement: amount },
                    },
            });

            const transaction = await tx.accountTransaction.create({
              data: {
                accountId: account.id,
                type: direction === 'CREDIT' ? 'ADMIN_CREDIT' : 'ADMIN_DEBIT',
                status: 'COMPLETED',
                amount,
                balanceBefore,
                balanceAfter: updatedAccount.cashBalance,
                referenceId,
                note: dto.note?.trim(),
                createdById: administratorId,
              },
            });

            return {
              result: {
                message:
                  direction === 'CREDIT'
                    ? '账户上分成功'
                    : '账户扣款成功',
                account: {
                  accountNumber: updatedAccount.accountNumber,
                  currency: updatedAccount.currency,
                  cashBalance: updatedAccount.cashBalance.toFixed(2),
                  buyingPower: updatedAccount.buyingPower.toFixed(2),
                  frozenBalance: updatedAccount.frozenBalance.toFixed(2),
                },
                transaction: {
                  id: transaction.id,
                  type: transaction.type,
                  status: transaction.status,
                  amount: transaction.amount.toFixed(2),
                  balanceBefore: transaction.balanceBefore.toFixed(2),
                  balanceAfter: transaction.balanceAfter.toFixed(2),
                  referenceId: transaction.referenceId,
                  note: transaction.note,
                  createdAt: transaction.createdAt,
                },
              },
              audit: {
                accountId: account.id,
                accountNumber: account.accountNumber,
                amount: amount.toFixed(2),
                referenceId,
                balanceBefore: balanceBefore.toFixed(2),
                balanceAfter: updatedAccount.cashBalance.toFixed(2),
              },
            };
          },
          {
            isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
          },
        );

        await this.auditService.createLog({
          actorId: administratorId,
          action:
            direction === 'CREDIT' ? 'ACCOUNT_CREDITED' : 'ACCOUNT_DEBITED',
          resource: 'ACCOUNT',
          resourceId: operation.audit.accountId,
          description:
            direction === 'CREDIT'
              ? `账户 ${operation.audit.accountNumber} 上分 ${operation.audit.amount}`
              : `账户 ${operation.audit.accountNumber} 扣款 ${operation.audit.amount}`,
          metadata: {
            accountNumber: operation.audit.accountNumber,
            amount: operation.audit.amount,
            referenceId: operation.audit.referenceId,
            balanceBefore: operation.audit.balanceBefore,
            balanceAfter: operation.audit.balanceAfter,
          },
        });

        return operation.result;
      } catch (error: unknown) {
        if (this.hasPrismaCode(error, 'P2002')) {
          throw new ConflictException('该付款流水号已处理');
        }

        if (this.hasPrismaCode(error, 'P2034') && attempt < 3) {
          continue;
        }

        throw error;
      }
    }

    throw new ConflictException(
      'Concurrent balance update detected; please retry',
    );
  }

  private hasPrismaCode(error: unknown, expectedCode: string): boolean {
    return (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      (error as { code?: unknown }).code === expectedCode
    );
  }
}
