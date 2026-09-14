import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { Prisma } from '../generated/prisma/client';
import { LoanStatus, UserRole } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { fixedInviteCode } from '../common/fixed-invite';
import { moneyDecimal } from '../common/money';

@Injectable()
export class LoansService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  private generateOrderNo() {
    const suffix = randomBytes(5).toString('hex').slice(0, 8).toUpperCase();
    const stamp = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    return `LN${stamp}${suffix}`;
  }

  private validateLoanAmount(value: unknown): number {
    if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
      throw new BadRequestException('金额必须为有效正数');
    }
    const amount = new Prisma.Decimal(value);
    if (amount.decimalPlaces() > 2 || amount.mul(100).greaterThan(Number.MAX_SAFE_INTEGER)) {
      throw new BadRequestException('金额最多保留两位小数且不能超出精度范围');
    }
    return value;
  }

  async clientLoans(userId: string) {
    return this.prisma.loanApplication.findMany({
      where: { account: { userId } }, orderBy: { createdAt: 'desc' },
      select: { id: true, orderNo: true, status: true, approvedAmount: true, outstandingAmount: true, createdAt: true },
    });
  }

  async apply(userId: string) {
    return this.prisma.$transaction(async (tx) => {
      const account = await tx.account.findUnique({ where: { userId } });
      if (!account) throw new NotFoundException('Trading account not found');
      // Lock the account so repeated requests reuse its pending application.
      await tx.$queryRaw`SELECT id FROM accounts WHERE id = ${account.id} FOR UPDATE`;
      const existing = await tx.loanApplication.findFirst({ where: { accountId: account.id, status: LoanStatus.PENDING } });
      if (existing) return { id: existing.id, status: existing.status };
      const loan = await tx.loanApplication.create({ data: {
        accountId: account.id, orderNo: this.generateOrderNo(), requestedAmount: 0,
      } });
      return { id: loan.id, status: loan.status };
    });
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
    const fixedCode = fixedInviteCode();
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
      ...(role === UserRole.SUPPORT
        ? { account: { user: { assignedBusinessId: userId, usedInviteCode: { code: fixedCode } } } }
        : {}),
      ...(role === UserRole.FINANCE
        ? { account: { user: { NOT: { usedInviteCode: { is: { code: fixedCode } } } } } }
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
    if (role !== UserRole.FINANCE) throw new ForbiddenException('Only finance can create loans');
    const amount = this.validateLoanAmount(body.amount);
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
            usedInviteCode: { select: { code: true } },
          },
        },
      },
    });

    if (!account) throw new NotFoundException('交易账号不存在');
    this.assertFinanceLoanVisible(role, account.user.usedInviteCode?.code);

    const loan = await this.prisma.loanApplication.create({
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

    await this.auditService.createLog({
      actorId: userId,
      action: 'LOAN_CREATE',
      resource: 'loan',
      resourceId: loan.id,
      description: `创建贷款申请 ${loan.orderNo}`,
      metadata: { orderNo: loan.orderNo, amount },
    });

    return loan;
  }

  async approve(
    id: string,
    operatorId: string,
    roleOrBody: UserRole | { approvedAmount: number; interestRate?: number; dueDate?: string; note?: string },
    body?: { approvedAmount: number; interestRate?: number; dueDate?: string; note?: string },
  ) {
    // Keep the pre-role service signature working for internal callers and
    // older tests while controllers use the role-aware form.
    const role = typeof roleOrBody === 'string' ? roleOrBody : UserRole.FINANCE;
    const requestBody = typeof roleOrBody === 'string' ? body : roleOrBody;
    if (!requestBody) throw new BadRequestException('批准参数不完整');
    const approvedAmount = this.validateLoanAmount(requestBody.approvedAmount);
    if (!Number.isFinite(approvedAmount) || approvedAmount <= 0) {
      throw new BadRequestException('批准金额不正确');
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const loan = await tx.loanApplication.findUnique({
        where: { id },
        include: { account: { include: { user: { include: { usedInviteCode: true } } } } },
      });
      if (!loan) throw new NotFoundException('贷款申请不存在');
      this.assertFinanceLoanVisible(role, loan.account.user?.usedInviteCode?.code);
      if (loan.status !== LoanStatus.PENDING) throw new ConflictException('贷款申请已被处理');

      const before = loan.account.cashBalance;
      const after = before.add(approvedAmount);

      const claimed = await tx.loanApplication.updateMany({
        where: { id, status: LoanStatus.PENDING },
        data: {
          approvedAmount,
          outstandingAmount: approvedAmount,
          interestRate: Number(requestBody.interestRate ?? loan.interestRate),
          dueDate: requestBody.dueDate ? new Date(requestBody.dueDate) : loan.dueDate,
          note: requestBody.note?.trim() || loan.note,
          status: LoanStatus.DISBURSED,
          approvedById: operatorId,
          approvedAt: new Date(),
          disbursedAt: new Date(),
        },
      });
      if (claimed.count !== 1) throw new ConflictException('贷款申请已被其他操作员处理');

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
          note: requestBody.note?.trim() || '贷款审核通过并自动到账',
          createdById: operatorId,
        },
      });

      return tx.loanApplication.findUniqueOrThrow({
        where: { id },
        include: this.includeCustomer(),
      });
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });

    await this.auditService.createLog({
      actorId: operatorId,
      action: 'LOAN_APPROVE_AUTO_CREDIT',
      resource: 'loan',
      resourceId: result.id,
      description: `贷款审核通过并自动到账 ${result.orderNo}`,
      metadata: { orderNo: result.orderNo, approvedAmount },
    });

    return result;
  }

  async reject(id: string, operatorId: string, role: UserRole, note?: string) {
    const loan = await this.prisma.loanApplication.findUnique({ where: { id }, include: { account: { include: { user: { include: { usedInviteCode: true } } } } } });
    if (!loan) throw new NotFoundException('贷款申请不存在');
    this.assertFinanceLoanVisible(role, loan.account.user.usedInviteCode?.code);
    if (loan.status !== LoanStatus.PENDING) throw new ConflictException('贷款申请已被处理');

    const claimed = await this.prisma.loanApplication.updateMany({
      where: { id, status: LoanStatus.PENDING },
      data: {
        status: LoanStatus.REJECTED,
        approvedById: operatorId,
        approvedAt: new Date(),
        note: note?.trim() || loan.note,
      },
    });
    if (claimed.count !== 1) throw new ConflictException('贷款申请已被其他操作员处理');
    const result = await this.prisma.loanApplication.findUniqueOrThrow({ where: { id }, include: this.includeCustomer() });

    await this.auditService.createLog({
      actorId: operatorId,
      action: 'LOAN_REJECT',
      resource: 'loan',
      resourceId: result.id,
      description: `拒绝贷款申请 ${result.orderNo}`,
      metadata: { orderNo: result.orderNo, note },
    });

    return result;
  }

  async disburse(id: string, operatorId: string, role: UserRole, note?: string) {
    const loan = await this.prisma.loanApplication.findUnique({
      where: { id },
      include: { account: { include: { user: { include: { usedInviteCode: true } } } } },
    });
    if (!loan) throw new NotFoundException('贷款申请不存在');
    this.assertFinanceLoanVisible(role, loan.account.user.usedInviteCode?.code);
    if (loan.status !== LoanStatus.APPROVED) throw new BadRequestException('贷款审核通过后已自动到账，无需重复放款');

    const amount = moneyDecimal(loan.approvedAmount ?? 0);
    if (amount.lte(0)) throw new BadRequestException('贷款批准金额不正确');

    return this.prisma.$transaction(async (tx) => {
      const before = moneyDecimal(loan.account.cashBalance);
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

  async repay(id: string, operatorId: string, role: UserRole, amount: number, note?: string) {
    const repayment = moneyDecimal(amount);
    if (!repayment.isFinite() || repayment.lte(0)) throw new BadRequestException('还款金额不正确');

    const loan = await this.prisma.loanApplication.findUnique({ where: { id }, include: { account: { include: { user: { include: { usedInviteCode: true } } } } } });
    if (!loan) throw new NotFoundException('贷款申请不存在');
    this.assertFinanceLoanVisible(role, loan.account.user.usedInviteCode?.code);
    if (
      loan.status !== LoanStatus.DISBURSED &&
      loan.status !== LoanStatus.PARTIAL_REPAID &&
      loan.status !== LoanStatus.OVERDUE
    ) {
      throw new BadRequestException('当前贷款状态不能登记还款');
    }

    const outstanding = moneyDecimal(loan.outstandingAmount);
    const remaining = outstanding.sub(repayment);
    const nextOutstanding = remaining.gt(0) ? remaining : new Prisma.Decimal(0);

    const result = await this.prisma.loanApplication.update({
      where: { id },
      data: {
        outstandingAmount: nextOutstanding,
        status: nextOutstanding.lte(0) ? LoanStatus.REPAID : LoanStatus.PARTIAL_REPAID,
        closedAt: nextOutstanding.lte(0) ? new Date() : null,
        note: note?.trim() || loan.note,
        approvedById: operatorId,
      },
      include: this.includeCustomer(),
    });

    await this.auditService.createLog({
      actorId: operatorId,
      action: 'LOAN_REPAY_RECORD',
      resource: 'loan',
      resourceId: result.id,
      description: `登记贷款还款 ${result.orderNo}`,
      metadata: {
        orderNo: result.orderNo,
        repayment: repayment.toFixed(2),
        outstandingAmount: nextOutstanding.toFixed(2),
      },
    });

    return result;
  }

  async markOverdue(id: string, role: UserRole) {
    const loan = await this.prisma.loanApplication.findUnique({ where: { id }, include: { account: { include: { user: { include: { usedInviteCode: true } } } } } });
    if (!loan) throw new NotFoundException('贷款申请不存在');
    this.assertFinanceLoanVisible(role, loan.account.user.usedInviteCode?.code);
    if (
      loan.status !== LoanStatus.DISBURSED &&
      loan.status !== LoanStatus.PARTIAL_REPAID
    ) {
      throw new BadRequestException('当前贷款状态不能标记逾期');
    }

    const result = await this.prisma.loanApplication.update({
      where: { id },
      data: {
        status: LoanStatus.OVERDUE,
      },
      include: this.includeCustomer(),
    });

    await this.auditService.createLog({
      action: 'LOAN_MARK_OVERDUE',
      resource: 'loan',
      resourceId: result.id,
      description: `标记贷款逾期 ${result.orderNo}`,
      metadata: { orderNo: result.orderNo },
    });

    return result;
  }

  private assertFinanceLoanVisible(role: UserRole, inviteCode?: string | null) {
    if (role !== UserRole.FINANCE) throw new ForbiddenException('Only finance can manage loans');
    const fixedCode = fixedInviteCode();
    if (role === UserRole.FINANCE && inviteCode?.toUpperCase() === fixedCode) {
      throw new NotFoundException('贷款申请不存在');
    }
  }
}
