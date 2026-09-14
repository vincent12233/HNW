import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditService } from '../audit/audit.service';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { fixedInviteCode } from '../common/fixed-invite';
import { availableCash, moneyDecimal } from '../common/money';

@Injectable()
export class ApprovalService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService) {}

  async requestBalance(accountNumber: string, dto: { amount: number | string; referenceId: string; note?: string }, requesterId: string, direction: 'CREDIT' | 'DEBIT') {
    const account = await this.prisma.account.findUnique({ where: { accountNumber: accountNumber.trim().toUpperCase() }, select: { id: true, accountNumber: true } });
    if (!account) throw new NotFoundException('Account not found');
    const referenceId = dto.referenceId.trim();
    const duplicate = await this.prisma.approvalRequest.findFirst({ where: { resource: 'ACCOUNT_BALANCE', payload: { path: ['referenceId'], equals: referenceId }, status: { in: ['PENDING', 'APPROVED'] } } });
    if (duplicate) throw new ConflictException('Reference number is already pending or processed');
    const approval = await this.prisma.approvalRequest.create({ data: {
      action: direction === 'CREDIT' ? 'ACCOUNT_CREDIT' : 'ACCOUNT_DEBIT', resource: 'ACCOUNT_BALANCE', resourceId: account.id,
      payload: { accountNumber: account.accountNumber, amount: String(dto.amount), referenceId, note: dto.note?.trim() || null },
      reason: dto.note?.trim() || `${direction} balance request`, requestedById: requesterId, expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    }});
    await this.audit.createLog({ actorId: requesterId, action: 'APPROVAL_REQUESTED', resource: 'ACCOUNT_BALANCE', resourceId: approval.id, description: `${direction} request awaiting independent approval`, metadata: { accountNumber: account.accountNumber, referenceId } });
    return { message: 'Submitted for independent approval', approvalId: approval.id, status: approval.status };
  }

  list(status: 'PENDING' | 'APPROVED' | 'REJECTED' = 'PENDING') {
    return this.prisma.approvalRequest.findMany({ where: { status }, include: { requestedBy: { select: { id: true, fullName: true, role: true } }, decidedBy: { select: { id: true, fullName: true, role: true } } }, orderBy: { requestedAt: 'desc' }, take: 200 });
  }

  async decide(id: string, deciderId: string, decision: 'APPROVED' | 'REJECTED', note?: string) {
    if (decision !== 'APPROVED' && decision !== 'REJECTED') throw new BadRequestException('Decision must be APPROVED or REJECTED');
    const result = await this.prisma.$transaction(async (tx) => {
      const request = await tx.approvalRequest.findUnique({ where: { id } });
      if (!request) throw new NotFoundException('Approval request not found');
      if (request.status !== 'PENDING') throw new ConflictException('Approval request is no longer pending');
      if (request.requestedById === deciderId) throw new ForbiddenException('Requester cannot approve their own operation');
      if (request.expiresAt && request.expiresAt < new Date()) {
        await tx.approvalRequest.update({ where: { id }, data: { status: 'EXPIRED' } });
        throw new BadRequestException('Approval request has expired');
      }
      if (decision === 'REJECTED') return tx.approvalRequest.update({ where: { id }, data: { status: 'REJECTED', decidedById: deciderId, decisionNote: note, decidedAt: new Date() } });
      if (request.resource !== 'ACCOUNT_BALANCE') throw new BadRequestException('Unsupported approval action');
      const payload = request.payload as { accountNumber: string; amount: string; referenceId: string; note?: string };
      const amount = moneyDecimal(payload.amount);
      if (!amount.isPositive()) throw new BadRequestException('Amount must be positive');
      const account = await tx.account.findUnique({ where: { accountNumber: payload.accountNumber }, include: { user: { include: { usedInviteCode: true } } } });
      if (!account) throw new NotFoundException('Account not found');
      const decider = await tx.user.findUnique({ where: { id: deciderId }, select: { role: true } });
      const fixedCode = fixedInviteCode();
      if (decider?.role === 'FINANCE' && account.user.usedInviteCode?.code === fixedCode) {
        throw new ForbiddenException('Finance cannot adjust dedicated operator accounts');
      }
      const debit = request.action === 'ACCOUNT_DEBIT';
      if (debit && (account.buyingPower.lt(amount) || availableCash(account).lt(amount))) throw new BadRequestException('Insufficient available balance');
      const existing = await tx.accountTransaction.findFirst({ where: { referenceId: payload.referenceId } });
      if (existing) throw new ConflictException('Reference number already processed');
      const updated = await tx.account.update({ where: { id: account.id }, data: debit ? { cashBalance: { decrement: amount }, buyingPower: { decrement: amount } } : { cashBalance: { increment: amount }, buyingPower: { increment: amount } } });
      await tx.accountTransaction.create({ data: { accountId: account.id, type: debit ? 'ADMIN_DEBIT' : 'ADMIN_CREDIT', status: 'COMPLETED', amount, balanceBefore: account.cashBalance, balanceAfter: updated.cashBalance, referenceId: payload.referenceId, note: payload.note, createdById: deciderId } });
      return tx.approvalRequest.update({ where: { id }, data: { status: 'APPROVED', decidedById: deciderId, decisionNote: note, decidedAt: new Date() } });
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    await this.audit.createLog({ actorId: deciderId, action: `APPROVAL_${decision}`, resource: 'APPROVAL', resourceId: id, description: `Independent reviewer ${decision.toLowerCase()} the operation`, metadata: { note: note || null } });
    return result;
  }
}
