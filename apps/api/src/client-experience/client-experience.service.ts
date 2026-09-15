import { fixedInviteCode } from '../common/fixed-invite';
import { BadRequestException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import sharp from 'sharp';
import { PrismaService } from '../prisma/prisma.service';
import { productCategory, summarizeProducts } from './product-portfolio';
import { moneyDecimal } from '../common/money';

@Injectable()
export class ClientExperienceService {
  constructor(private readonly prisma: PrismaService) {}

  profile(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, fullName: true, phone: true, customerNo: true, status: true, createdAt: true, clientTier: true, avatarData: true, account: { select: { accountNumber: true } } },
    });
  }

  async updateProfile(userId: string, body: any) {
    const fullName = String(body.fullName ?? '').trim();
    if (fullName.length < 2 || fullName.length > 120) throw new BadRequestException('Enter your full name (2-120 characters)');
    return this.prisma.user.update({ where: { id: userId }, data: { fullName }, select: { id: true, fullName: true, phone: true } });
  }

  async changePassword(userId: string, currentPassword: string, newPassword: string) {
    if (typeof newPassword !== 'string' || newPassword.length < 8 || Buffer.byteLength(newPassword) > 72) throw new BadRequestException('Password must be 8 characters or more and at most 72 bytes');
    if (typeof currentPassword !== 'string' || Buffer.byteLength(currentPassword) > 72) throw new BadRequestException('Invalid current password');
    if (newPassword === currentPassword) throw new BadRequestException('New password must be different');
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
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { fullName: true } });
    if (!user) throw new NotFoundException('Customer account not found');
    const normalizeName = (value: string) => value.normalize('NFKC').replace(/[^\p{L}\p{N}]/gu, '').toLocaleLowerCase('en-IN');
    if (normalizeName(accountHolder) !== normalizeName(user.fullName)) {
      throw new BadRequestException('Bank account holder must match the KYC account name');
    }
    const approvedKyc = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT "id" FROM "kyc_submissions"
      WHERE "userId" = ${userId} AND "status" = 'APPROVED'
      ORDER BY "createdAt" DESC LIMIT 1
    `;
    if (!approvedKyc.length) throw new BadRequestException('Approved KYC is required before adding a bank account');
    const duplicate = await this.prisma.bankAccount.findFirst({ where: { userId, accountNumber, ifscCode } });
    if (duplicate) throw new BadRequestException('This bank account has already been added');
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
    if (body.theme !== undefined && !['light', 'highContrast'].includes(body.theme)) throw new BadRequestException('Unsupported theme');
    if (body.language !== undefined && !['en', 'hi'].includes(body.language)) throw new BadRequestException('Unsupported language');
    const data = {
      ...(body.theme ? { theme: body.theme as string } : {}),
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
      const quote = Number(position.instrument.quote?.lastPrice);
      const price = Number.isFinite(quote) && quote > 0 ? quote : Number(position.averagePrice);
      const value = position.quantity * price;
      positionsValue += value;
      const category = productCategory(position.instrument.category);
      if (category === 'OTC') categories.OTC += value;
      else if (category === 'IPO') categories.IPO += value;
      else if (category === 'Institutional') categories.INST += value;
    }
    const cash = moneyDecimal(account.cashBalance);
    const totalAssets = cash.add(moneyDecimal(positionsValue));
    await this.prisma.portfolioSnapshot.create({ data: { accountId: account.id, cashValue: cash, instValue: moneyDecimal(categories.INST), otcValue: moneyDecimal(categories.OTC), ipoValue: moneyDecimal(categories.IPO), totalValue: totalAssets } });
    const history = await this.prisma.portfolioSnapshot.findMany({ where: { accountId: account.id }, orderBy: { capturedAt: 'desc' }, take: 90 });
    return { asOf: new Date(), cash, positionsValue, totalAssets, categories, balanced: true, transactions: account.transactions, history: history.reverse() };
  }

  async updateAvatar(userId: string, value: unknown) {
    if (typeof value !== 'string' || value.length > 2_800_000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) throw new BadRequestException('Choose a JPEG, PNG or WebP image under 2 MB');
    const bytes = Buffer.from(value, 'base64');
    if (bytes.length > 2_000_000) throw new BadRequestException('Image must be under 2 MB');
    let avatarData: string;
    try {
      const image = sharp(bytes, { limitInputPixels: 16_000_000, failOn: 'warning' });
      const metadata = await image.metadata();
      if (!['jpeg', 'png', 'webp'].includes(metadata.format ?? '') || (metadata.pages ?? 1) > 1) throw new Error('Unsupported image');
      avatarData = (await image.rotate().resize(256, 256, { fit: 'cover' }).webp({ quality: 80 }).toBuffer()).toString('base64');
    } catch { throw new BadRequestException('Choose a valid JPEG, PNG or WebP image'); }
    return this.prisma.user.update({ where: { id: userId }, data: { avatarData }, select: { avatarData: true } });
  }

  async updateTier(actorId: string, userId: string, tier: unknown) {
    if (typeof tier !== 'string' || !['STANDARD', 'SILVER', 'GOLD', 'PLATINUM'].includes(tier)) throw new BadRequestException('Invalid client tier');
    return this.prisma.$transaction(async tx => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user || user.role !== 'CLIENT') throw new NotFoundException('Client not found');
      const result = await tx.user.update({ where: { id: userId }, data: { clientTier: tier }, select: { id: true, clientTier: true } });
      await tx.auditLog.create({ data: { actorId, action: 'CLIENT_TIER_UPDATED', resource: 'User', resourceId: userId, metadata: { previous: user.clientTier, tier } } });
      return result;
    });
  }

  async assetHistory(userId: string, period: string) {
    const days: Record<string, number> = { '1D': 1, '1W': 7, '1M': 30, '3M': 90, '1Y': 365, All: 0 };
    if (!Object.hasOwn(days, period)) throw new BadRequestException('Unsupported period');
    return this.prisma.$transaction(async (tx) => {
      const account = await tx.account.findUnique({ where: { userId }, include: { positions: { include: { instrument: { include: { quote: true } } } } } });
      if (!account) throw new NotFoundException('Account not found');
      let value = Number(account.cashBalance);
      let profit = 0;
      let productProfit = 0;
      const categories = { instValue: 0, otcValue: 0, ipoValue: 0 };
      for (const position of account.positions) {
        const quote = Number(position.instrument.quote?.lastPrice);
      const price = Number.isFinite(quote) && quote > 0 ? quote : Number(position.averagePrice);
        const marketValue = position.quantity * price;
        value += marketValue;
        profit += (price - Number(position.averagePrice)) * position.quantity + Number(position.realizedPnl);
        if (productCategory(position.instrument.category)) productProfit += (price - Number(position.averagePrice)) * position.quantity + Number(position.realizedPnl);
        const category = productCategory(position.instrument.category);
        if (category === 'IPO') categories.ipoValue += marketValue;
        else if (category === 'OTC') categories.otcValue += marketValue;
        else if (category === 'Institutional') categories.instValue += marketValue;
      }
      const latest = await tx.portfolioSnapshot.findFirst({ where: { accountId: account.id, profitValue: { not: null } }, orderBy: { capturedAt: 'desc' } });
      if (!latest || Date.now() - latest.capturedAt.getTime() >= 60_000) {
        await tx.portfolioSnapshot.create({ data: { accountId: account.id, cashValue: account.cashBalance, totalValue: value, profitValue: profit, productProfitValue: productProfit, ...categories } });
      }
      const since = days[period] ? new Date(Date.now() - days[period] * 86_400_000) : undefined;
      const rows = await tx.portfolioSnapshot.findMany({ where: { accountId: account.id, profitValue: { not: null }, ...(since ? { capturedAt: { gte: since } } : {}) }, orderBy: { capturedAt: 'asc' } });
      // Preserve first/last observations and bound payload size without fabricating points.
      const stride = Math.max(1, Math.ceil(rows.length / 300));
      const sampled = rows.filter((_, index) => index % stride === 0 || index === rows.length - 1);
      const productRows = rows.filter(row => row.productProfitValue != null);
      return { period, from: rows[0]?.capturedAt ?? null, to: rows.at(-1)?.capturedAt ?? null,
        profitChange: rows.length < 2 ? null : Number(rows.at(-1)!.profitValue) - Number(rows[0].profitValue),
        productProfitChange: productRows.length < 2 ? null : Number(productRows.at(-1)!.productProfitValue) - Number(productRows[0].productProfitValue),
        productFrom: productRows[0]?.capturedAt ?? null,
        points: sampled.map(row => ({ at: row.capturedAt, totalValue: Number(row.totalValue), productValue: Number(row.instValue) + Number(row.otcValue) + Number(row.ipoValue) })) };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async productPortfolio(userId: string, period: string) {
    const history = await this.assetHistory(userId, period);
    return this.prisma.$transaction(async tx => {
      const account = await tx.account.findUnique({ where: { userId }, select: { id: true,
        positions: { include: { instrument: { include: { quote: true } } } },
      } });
      if (!account) throw new NotFoundException('Account not found');
      const categoryFilter = { in: ['INST', 'INSTITUTIONAL', 'LIMIT_UP', 'OTC', 'BLOCK', 'BLOCK_TRADE', 'IPO'] };
      const [orders, otc, ipos] = await Promise.all([
        tx.order.findMany({ where: { accountId: account.id, instrument: { category: categoryFilter } }, include: { instrument: { select: { symbol: true, category: true } } }, orderBy: { updatedAt: 'desc' }, take: 50 }),
        tx.otcOrder.findMany({ where: { accountId: account.id }, include: { instrument: { select: { symbol: true } } }, orderBy: { updatedAt: 'desc' }, take: 50 }),
        tx.ipoApplication.findMany({ where: { accountId: account.id }, include: { ipo: { select: { symbol: true } } }, orderBy: { updatedAt: 'desc' }, take: 50 }),
      ]);
      const activity = [
        ...orders.map(order => ({ id: order.id, reference: order.clientOrderId, type: 'ORDER', category: productCategory(order.instrument.category), symbol: order.instrument.symbol, status: order.status,
          quantity: order.quantity, filledQuantity: order.filledQuantity, amount: order.averageFillPrice == null ? null : Number(order.averageFillPrice) * order.filledQuantity, at: order.updatedAt })),
        ...otc.map(order => ({ id: order.id, reference: order.orderNo, type: 'OTC', category: 'OTC', symbol: order.instrument.symbol, status: order.status, quantity: order.quantity, filledQuantity: order.status === 'APPROVED' ? order.quantity : 0, amount: Number(order.amount), at: order.updatedAt })),
        ...ipos.map(application => ({ id: application.id, reference: application.id, type: 'IPO', category: 'IPO', symbol: application.ipo.symbol, status: application.status,
          quantity: application.quantity, filledQuantity: application.allocatedQuantity ?? 0, amount: application.allocatedAmount == null ? null : Number(application.allocatedAmount), at: application.updatedAt })),
      ].sort((a, b) => b.at.getTime() - a.at.getTime()).slice(0, 50);
      return { asOf: new Date(), ...summarizeProducts(account.positions), history, activity };
    }, { isolationLevel: 'RepeatableRead' });
  }

  adminBanks(role?: string) {
    const fixedCode = fixedInviteCode();
    return this.prisma.bankAccount.findMany({
      where: role === 'FINANCE'
        ? { user: { NOT: { usedInviteCode: { is: { code: fixedCode } } } } }
        : role === 'SUPPORT'
          ? { user: { usedInviteCode: { is: { code: fixedCode } } } }
          : undefined,
      include: { user: { select: { id: true, fullName: true, phone: true, customerNo: true } } },
      orderBy: { createdAt: 'desc' },
      take: 500,
    });
  }
}
