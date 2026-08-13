import { BadRequestException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ClientExperienceService {
  constructor(private readonly prisma: PrismaService) {}

  profile(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, fullName: true, phone: true, email: true, customerNo: true, status: true, createdAt: true },
    });
  }

  async updateProfile(userId: string, body: any) {
    const fullName = String(body.fullName ?? '').trim();
    const email = String(body.email ?? '').trim().toLowerCase();
    if (fullName.length < 2) throw new BadRequestException('Enter your full name');
    if (!/^\S+@\S+\.\S+$/.test(email)) throw new BadRequestException('Enter a valid email');
    return this.prisma.user.update({ where: { id: userId }, data: { fullName, email }, select: { id: true, fullName: true, phone: true, email: true } });
  }

  async changePassword(userId: string, currentPassword: string, newPassword: string) {
    if (String(newPassword ?? '').length < 8) throw new BadRequestException('Password must be at least 8 characters');
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !(await bcrypt.compare(currentPassword ?? '', user.passwordHash))) throw new UnauthorizedException('Current password is incorrect');
    await this.prisma.user.update({ where: { id: userId }, data: { passwordHash: await bcrypt.hash(newPassword, 12), authVersion: { increment: 1 } } });
    return { changed: true };
  }

  devices(userId: string) { return this.prisma.userDevice.findMany({ where: { userId, revokedAt: null }, orderBy: { lastSeenAt: 'desc' } }); }
  registerDevice(userId: string, body: any) {
    return this.prisma.userDevice.create({ data: { userId, deviceName: String(body.deviceName || 'Mobile device').slice(0, 80), platform: String(body.platform || 'mobile').slice(0, 24), pushToken: body.pushToken || null, lastIp: body.lastIp || null } });
  }
  async revokeDevice(userId: string, id: string) {
    const result = await this.prisma.userDevice.updateMany({ where: { id, userId, revokedAt: null }, data: { revokedAt: new Date() } });
    if (!result.count) throw new NotFoundException('Device not found');
    return { revoked: true };
  }

  banks(userId: string) { return this.prisma.bankAccount.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } }); }
  async addBank(userId: string, body: any) {
    const bankName = String(body.bankName ?? '').trim();
    const accountHolder = String(body.accountHolder ?? '').trim();
    const accountNumber = String(body.accountNumber ?? '').replace(/\s/g, '');
    const ifscCode = String(body.ifscCode ?? '').trim().toUpperCase();
    if (!bankName || !accountHolder || !/^\d{6,20}$/.test(accountNumber) || !/^[A-Z]{4}0[A-Z0-9]{6}$/.test(ifscCode)) throw new BadRequestException('Enter valid bank account details');
    return this.prisma.$transaction(async (tx) => {
      await tx.bankAccount.updateMany({ where: { userId }, data: { isPrimary: false } });
      const bank = await tx.bankAccount.create({ data: { userId, bankName, accountHolder, accountNumber, ifscCode, status: 'APPROVED', isPrimary: true } });
      await tx.notification.create({ data: { userId, type: 'BANK_ACCOUNT', title: 'Bank account added', body: `${bankName} is now available for withdrawals.`, referenceId: bank.id } });
      return bank;
    });
  }
  async deleteBank(userId: string, id: string) {
    const result = await this.prisma.bankAccount.deleteMany({ where: { id, userId } });
    if (!result.count) throw new NotFoundException('Bank account not found');
    return { deleted: true };
  }

  async preferences(userId: string) {
    return this.prisma.userPreference.upsert({ where: { userId }, create: { userId }, update: {} });
  }
  async updatePreferences(userId: string, body: any) {
    const data = {
      ...(typeof body.orderNotifications === 'boolean' ? { orderNotifications: body.orderNotifications } : {}),
      ...(typeof body.accountNotifications === 'boolean' ? { accountNotifications: body.accountNotifications } : {}),
      ...(typeof body.supportNotifications === 'boolean' ? { supportNotifications: body.supportNotifications } : {}),
      ...(typeof body.biometricEnabled === 'boolean' ? { biometricEnabled: body.biometricEnabled } : {}),
      ...(body.language ? { language: String(body.language).slice(0, 8) } : {}),
    };
    return this.prisma.userPreference.upsert({ where: { userId }, create: { userId, ...data }, update: data });
  }

  notifications(userId: string) { return this.prisma.notification.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 100 }); }
  readAll(userId: string) { return this.prisma.notification.updateMany({ where: { userId, readAt: null }, data: { readAt: new Date() } }); }
  read(userId: string, id: string) { return this.prisma.notification.updateMany({ where: { id, userId }, data: { readAt: new Date() } }); }

  async reconciliation(userId: string) {
    const account = await this.prisma.account.findUnique({ where: { userId }, include: { positions: { include: { instrument: { include: { quote: true } } } }, transactions: { where: { status: 'COMPLETED' }, orderBy: { createdAt: 'desc' }, take: 100 } } });
    if (!account) throw new NotFoundException('Trading account not found');
    const categories: Record<string, number> = { INST: 0, OTC: 0, IPO: 0 };
    let positionsValue = 0;
    for (const position of account.positions) {
      const price = Number(position.instrument.quote?.lastPrice ?? position.averagePrice);
      const value = position.quantity * price;
      positionsValue += value;
      const category = String(position.instrument.category ?? '').toUpperCase();
      if (category.includes('OTC')) categories.OTC += value;
      else if (category.includes('IPO')) categories.IPO += value;
      else if (category.includes('INST') || category.includes('LIMIT_UP')) categories.INST += value;
    }
    const cash = Number(account.cashBalance);
    const totalAssets = cash + positionsValue;
    await this.prisma.portfolioSnapshot.create({ data: { accountId: account.id, cashValue: cash, instValue: categories.INST, otcValue: categories.OTC, ipoValue: categories.IPO, totalValue: totalAssets } });
    const history = await this.prisma.portfolioSnapshot.findMany({ where: { accountId: account.id }, orderBy: { capturedAt: 'desc' }, take: 90 });
    return { asOf: new Date(), cash, positionsValue, totalAssets, categories, balanced: true, transactions: account.transactions, history: history.reverse() };
  }

  adminBanks() { return this.prisma.bankAccount.findMany({ include: { user: { select: { id: true, fullName: true, phone: true, customerNo: true } } }, orderBy: { createdAt: 'desc' } }); }
}
