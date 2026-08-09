import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { LoanStatus, UserRole } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class LoansService {
  constructor(private readonly prisma: PrismaService) {}

  private generateOrderNo() {
    const suffix = Math.random().toString(36).slice(2, 8).toUpperCase();
    const stamp = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    return `LN${stamp}${suffix}`;
  }

  private includeCustomer() {
    return {
      account: {
        select: {
          id: true,
          accountNumber: true,
          cashBalance: true,
          buyingPower: true,
          currency: true,
          user: {
            select: {
              id: true,
              customerNo: true,
              fullName: true,
              phone: true,
              status: true,
              assignedBusinessId: true,
            },
          },
        },
      },
    };
  }

  async list(userId: string, role: UserRole, query: { search?: string; status?: LoanStatus }) {
    const search = query.search?.trim();
    const where: Prisma.LoanApplicationWhereInput = {
      ...(query.status ? { status: query.status } : {}),
      ...(role === UserRole.BUSINESS
        ? {
            account: {
              user: {
                assignedBusinessId: userId,
              },
            },
          }
        : {}),
      ...(search
        ? {
            OR: [
              { orderNo: { contains: search, mode: 'insensitive' } },
              { account: { accountNumber: { contains: search, mode: 'insensitive' } } },
              { account: { user: { fullName: { contains: search, mode: 'insensitive' } } } },
              { account: { user: { phone: { contains: search, mode: 'insensitive' } } } },
              { account: { user: { customerNo: { contains: search, mode: 'insensitive' } } } },
            ],
          }
        : {}),
    };

    return this.prisma.loanApplication.findMany({
      where,
      include: this.includeCustomer(),
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async create(
    userId: string,
    role: UserRole,
    body: {
      accountNumber: string;
      amount: number;
      interestRate?: number;
      dueDate?: string;
      note?: string;
    },
  ) {
    const amount = Number(body.amount);
    if (!body.accountNumber?.trim()) throw new BadRequestException('请输入交易账号');
    if (!Number.isFinite(amount) || amount <= 0) throw new BadRequestException('贷款金额不正确');

    const account = await this.prisma.account.findUnique({
      where: {
        accountNumber: body.accountNumber.trim(),
      },
      include: {
        user: {
          select: {
            assignedBusinessId: true,
          },
        },
      },
    });

    if (!account) throw new NotFoundException('交易账号不存在');
    if (role === UserRole.BUSINESS && account.user.assignedBusinessId !== userId) {
      throw new ForbiddenException('只能为自己名下客户创建贷款申请');
    }

    return this.prisma.loanApplication.create({
      data: {
        orderNo: this.generateOrderNo(),
        accountId: account.id,
        requestedAmount: amount,
        interestRate: Number(body.interestRate ?? 0),
        dueDate: body.dueDate ? new Date(body.dueDate) : undefined,
        note: body.note?.trim() || undefined,
      },
      include: this.includeCustomer(),
    });
  }

  async approve(
    id: string,
    operatorId: string,
    body: { approvedAmount: number; interestRate?: number; dueDate?: string; note?: string },
  ) {
    const approvedAmount = Number(body.approvedAmount);
    if (!Number.isFinite(approvedAmount) || approvedAmount <= 0) {
      throw new BadRequestException('批准金额不正确');
    }

    const loan = await this.prisma.loanApplication.findUnique({
      where: { id },
      include: { account: true },
    });
    if (!loan) throw new NotFoundException('贷款申请不存在');
    if (loan.status !== LoanStatus.PENDING) throw new BadRequestException('只有待审核贷款可以批准');

    return this.prisma.$transaction(async (tx) => {
      const before = loan.account.cashBalance;
      const after = before.add(approvedAmount);

      await tx.account.update({
        where: { id: loan.accountId },
        data: {
          cashBalance: after,
          buyingPower: { increment: approvedAmount },
        },
      });

      await tx.accountTransaction.create({
        data: {
          accountId: loan.accountId,
          type: 'LOAN_DISBURSEMENT',
          status: 'COMPLETED',
          amount: approvedAmount,
          balanceBefore: before,
          balanceAfter: after,
          referenceId: loan.orderNo,
          note: body.note?.trim() || '贷款审核通过并自动到账',
          createdById: operatorId,
        },
      });

      return tx.loanApplication.update({
        where: { id },
        data: {
          approvedAmount,
          outstandingAmount: approvedAmount,
          interestRate: Number(body.interestRate ?? loan.interestRate),
          dueDate: body.dueDate ? new Date(body.dueDate) : loan.dueDate,
          note: body.note?.trim() || loan.note,
          status: LoanStatus.DISBURSED,
          approvedById: operatorId,
          approvedAt: new Date(),
          disbursedAt: new Date(),
        },
        include: this.includeCustomer(),
      });
    });
  }

  async reject(id: string, operatorId: string, note?: string) {
    const loan = await this.prisma.loanApplication.findUnique({ where: { id } });
    if (!loan) throw new NotFoundException('贷款申请不存在');
    if (loan.status !== LoanStatus.PENDING) throw new BadRequestException('只有待审核贷款可以拒绝');

    return this.prisma.loanApplication.update({
      where: { id },
      data: {
        status: LoanStatus.REJECTED,
        approvedById: operatorId,
        approvedAt: new Date(),
        note: note?.trim() || loan.note,
      },
      include: this.includeCustomer(),
    });
  }

  async disburse(id: string, operatorId: string, note?: string) {
    const loan = await this.prisma.loanApplication.findUnique({
      where: { id },
      include: { account: true },
    });
    if (!loan) throw new NotFoundException('贷款申请不存在');
    if (loan.status !== LoanStatus.APPROVED) throw new BadRequestException('贷款审核通过后已自动到账，无需重复放款');

    const amount = Number(loan.approvedAmount ?? 0);
    if (amount <= 0) throw new BadRequestException('贷款批准金额不正确');

    return this.prisma.$transaction(async (tx) => {
      const before = loan.account.cashBalance;
      const after = before.add(amount);

      await tx.account.update({
        where: { id: loan.accountId },
        data: {
          cashBalance: after,
          buyingPower: { increment: amount },
        },
      });

      await tx.accountTransaction.create({
        data: {
          accountId: loan.accountId,
          type: 'LOAN_DISBURSEMENT',
          status: 'COMPLETED',
          amount,
          balanceBefore: before,
          balanceAfter: after,
          referenceId: loan.orderNo,
          note: note?.trim() || '贷款放款',
          createdById: operatorId,
        },
      });

      return tx.loanApplication.update({
        where: { id },
        data: {
          status: LoanStatus.DISBURSED,
          disbursedAt: new Date(),
          note: note?.trim() || loan.note,
        },
        include: this.includeCustomer(),
      });
    });
  }

  async repay(id: string, operatorId: string, amount: number, note?: string) {
    const repayment = Number(amount);
    if (!Number.isFinite(repayment) || repayment <= 0) throw new BadRequestException('还款金额不正确');

    const loan = await this.prisma.loanApplication.findUnique({ where: { id } });
    if (!loan) throw new NotFoundException('贷款申请不存在');
    if (
      loan.status !== LoanStatus.DISBURSED &&
      loan.status !== LoanStatus.PARTIAL_REPAID &&
      loan.status !== LoanStatus.OVERDUE
    ) {
      throw new BadRequestException('当前贷款状态不能登记还款');
    }

    const outstanding = Number(loan.outstandingAmount);
    const nextOutstanding = Math.max(outstanding - repayment, 0);

    return this.prisma.loanApplication.update({
      where: { id },
      data: {
        outstandingAmount: nextOutstanding,
        status: nextOutstanding <= 0 ? LoanStatus.REPAID : LoanStatus.PARTIAL_REPAID,
        closedAt: nextOutstanding <= 0 ? new Date() : null,
        note: note?.trim() || loan.note,
        approvedById: operatorId,
      },
      include: this.includeCustomer(),
    });
  }

  async markOverdue(id: string) {
    const loan = await this.prisma.loanApplication.findUnique({ where: { id } });
    if (!loan) throw new NotFoundException('贷款申请不存在');
    if (
      loan.status !== LoanStatus.DISBURSED &&
      loan.status !== LoanStatus.PARTIAL_REPAID
    ) {
      throw new BadRequestException('当前贷款状态不能标记逾期');
    }

    return this.prisma.loanApplication.update({
      where: { id },
      data: {
        status: LoanStatus.OVERDUE,
      },
      include: this.includeCustomer(),
    });
  }
}
