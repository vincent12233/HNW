import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class OperatorService {
  constructor(private readonly prisma: PrismaService) {}

  private scope() {
    const fixedCode = (process.env.ADMIN_FIXED_INVITE_CODE?.trim().toUpperCase() || 'ADMINFIXED2026');
    return {
      role: 'CLIENT' as const,
      usedInviteCode: { code: fixedCode },
    };
  }

  listCustomers() {
    return this.prisma.user.findMany({
      where: this.scope(),
      select: {
        id: true,
        customerNo: true,
        fullName: true,
        phone: true,
        status: true,
        createdAt: true,
        usedInviteCode: { select: { code: true, usedAt: true } },
        account: {
          select: {
            accountNumber: true,
            currency: true,
            cashBalance: true,
            buyingPower: true,
            frozenBalance: true,
            isLive: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getCustomer(customerId: string) {
    const customer = await this.prisma.user.findFirst({
      where: { ...this.scope(), id: customerId },
      select: {
        id: true,
        customerNo: true,
        fullName: true,
        phone: true,
        status: true,
        createdAt: true,
        usedInviteCode: { select: { code: true, usedAt: true } },
        account: {
          select: {
            accountNumber: true,
            currency: true,
            cashBalance: true,
            buyingPower: true,
            frozenBalance: true,
            isLive: true,
            positions: {
              where: { quantity: { gt: 0 } },
              select: { quantity: true, frozenQuantity: true, averagePrice: true, instrument: { select: { symbol: true, name: true } } },
            },
          },
        },
      },
    });
    if (!customer) throw new NotFoundException('客户不属于专用运营员邀请码范围');
    return customer;
  }
}
