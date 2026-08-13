import { BadRequestException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class OtcService {
  constructor(private readonly prisma: PrismaService) {}

  async listOffers() {
    const now = new Date();
    const offers = await this.prisma.otcOffer.findMany({
      where: { isActive: true, validFrom: { lte: now }, validUntil: { gte: now } },
      include: { instrument: true },
      orderBy: { updatedAt: 'desc' },
    });
    return offers.map(({ keyHashTier1, keyHashTier2, keyHashTier3, ...offer }) => ({
      ...offer,
      tiers: [
        { tier: 1, price: offer.price, profit: offer.profitTier1 },
        ...(offer.priceTier2 ? [{ tier: 2, price: offer.priceTier2, profit: offer.profitTier2 }] : []),
        ...(offer.priceTier3 ? [{ tier: 3, price: offer.priceTier3, profit: offer.profitTier3 }] : []),
      ],
    }));
  }

  async listAdminOffers() {
    const offers = await this.prisma.otcOffer.findMany({ include: { instrument: true }, orderBy: { updatedAt: 'desc' } });
    return offers.map(({ keyHashTier1, keyHashTier2, keyHashTier3, ...offer }) => offer);
  }

  async saveOffer(body: { instrumentId: string; tiers: Array<{ price: string; profit: string; transactionKey: string }>; validFrom: string; validUntil: string }) {
    if (!Array.isArray(body.tiers) || body.tiers.length !== 3) throw new BadRequestException('Exactly three OTC price tiers are required');
    const tiers = body.tiers.map((tier) => ({
      price: new Prisma.Decimal(tier.price), profit: new Prisma.Decimal(tier.profit), key: tier.transactionKey?.trim(),
    }));
    if (tiers.some((tier) => !tier.price.greaterThan(0) || !tier.profit.greaterThan(0) || !/^\d{6}$/.test(tier.key))) {
      throw new BadRequestException('Each tier requires a valid price, profit and unique 6-digit transaction key');
    }
    if (new Set(tiers.map((tier) => tier.key)).size !== 3) throw new BadRequestException('Each OTC tier must use a different transaction key');
    const price = tiers[0].price;
    const validFrom = new Date(body.validFrom);
    const validUntil = new Date(body.validUntil);
    if (!price.greaterThan(0) || !Number.isFinite(validFrom.getTime()) || validUntil <= validFrom) {
      throw new BadRequestException('Valid price and offer period are required');
    }
    const instrument = await this.prisma.instrument.findUnique({ where: { id: body.instrumentId } });
    if (!instrument?.isActive) throw new NotFoundException('Active instrument not found');
    await this.prisma.instrument.update({
      where: { id: instrument.id },
      data: { category: 'OTC' },
    });
    const saved = await this.prisma.otcOffer.upsert({
      where: { instrumentId: instrument.id },
      create: { instrumentId: instrument.id, price, priceTier2: tiers[1].price, priceTier3: tiers[2].price, profitTier1: tiers[0].profit, profitTier2: tiers[1].profit, profitTier3: tiers[2].profit, keyHashTier1: await bcrypt.hash(tiers[0].key, 12), keyHashTier2: await bcrypt.hash(tiers[1].key, 12), keyHashTier3: await bcrypt.hash(tiers[2].key, 12), validFrom, validUntil },
      update: { price, priceTier2: tiers[1].price, priceTier3: tiers[2].price, profitTier1: tiers[0].profit, profitTier2: tiers[1].profit, profitTier3: tiers[2].profit, keyHashTier1: await bcrypt.hash(tiers[0].key, 12), keyHashTier2: await bcrypt.hash(tiers[1].key, 12), keyHashTier3: await bcrypt.hash(tiers[2].key, 12), validFrom, validUntil, isActive: true },
      include: { instrument: true },
    });
    const { keyHashTier1, keyHashTier2, keyHashTier3, ...offer } = saved;
    return offer;
  }

  async updateOffer(id: string, body: { price?: string; validFrom?: string; validUntil?: string; isActive?: boolean }) {
    const existing = await this.prisma.otcOffer.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('OTC offer not found');
    const price = body.price == null ? existing.price : new Prisma.Decimal(body.price);
    const validFrom = body.validFrom == null ? existing.validFrom : new Date(body.validFrom);
    const validUntil = body.validUntil == null ? existing.validUntil : new Date(body.validUntil);
    if (!price.greaterThan(0) || !Number.isFinite(validFrom.getTime()) || validUntil <= validFrom) {
      throw new BadRequestException('Valid price and offer period are required');
    }
    const saved = await this.prisma.otcOffer.update({ where: { id }, data: { price, validFrom, validUntil, isActive: body.isActive ?? existing.isActive }, include: { instrument: true } });
    const { keyHashTier1, keyHashTier2, keyHashTier3, ...offer } = saved;
    return offer;
  }

  async submit(userId: string, offerId: string, priceTier: number, quantity: number, key: string) {
    if (!Number.isInteger(quantity) || quantity <= 0 || quantity > 1000000) {
      throw new BadRequestException('Quantity must be a positive whole number');
    }
    const user = await this.prisma.user.findUnique({ where: { id: userId }, include: { account: true } });
    if (!user?.account) throw new NotFoundException('Trading account not found');
    const offer = await this.prisma.otcOffer.findUnique({ where: { id: offerId }, include: { instrument: true } });
    const now = new Date();
    if (!offer || !offer.isActive || offer.validFrom > now || offer.validUntil < now) {
      throw new BadRequestException('OTC offer is not active');
    }
    if (![1, 2, 3].includes(priceTier)) throw new BadRequestException('Invalid OTC price tier');
    const tierPrices = [offer.price, offer.priceTier2, offer.priceTier3];
    const tierHashes = [offer.keyHashTier1, offer.keyHashTier2, offer.keyHashTier3];
    const selectedPrice = tierPrices[priceTier - 1];
    const selectedHash = tierHashes[priceTier - 1];
    if (!selectedPrice || !selectedHash || !(await bcrypt.compare(key ?? '', selectedHash))) throw new UnauthorizedException('Invalid transaction key for this OTC price');
    const amount = selectedPrice.mul(quantity).toDecimalPlaces(2);
    const order = await this.prisma.otcOrder.create({
      data: {
        orderNo: `OTC-${Date.now()}-${Math.random().toString(36).slice(2, 8).toUpperCase()}`,
        accountId: user.account.id,
        offerId: offer.id,
        instrumentId: offer.instrumentId,
        quantity,
        price: selectedPrice,
        priceTier,
        amount,
      },
      include: { instrument: true },
    });
    await this.prisma.notification.create({
      data: { userId, type: 'OTC', title: 'OTC order pending review', body: `${offer.instrument.symbol} · ${quantity} shares is awaiting review.`, referenceId: order.id },
    });
    return order;
  }

  async myOrders(userId: string) {
    return this.prisma.otcOrder.findMany({ where: { account: { userId } }, include: { instrument: true }, orderBy: { createdAt: 'desc' } });
  }

  async pendingOrders(reviewerId: string) {
    const reviewer = await this.prisma.user.findUnique({ where: { id: reviewerId } });
    return this.prisma.otcOrder.findMany({
      where: {
        status: 'PENDING',
        ...(reviewer?.role === 'BUSINESS' ? { account: { user: { assignedBusinessId: reviewerId } } } : {}),
      },
      include: { instrument: true, account: { include: { user: true } } },
      orderBy: { createdAt: 'asc' },
    });
  }

  approve(reviewerId: string, orderId: string) {
    return this.prisma.$transaction(async (tx) => {
      const order = await tx.otcOrder.findUnique({ where: { id: orderId }, include: { account: { include: { user: true } } } });
      if (!order) throw new NotFoundException('OTC order not found');
      if (order.status !== 'PENDING') throw new BadRequestException('OTC order already reviewed');
      const reviewer = await tx.user.findUnique({ where: { id: reviewerId } });
      if (reviewer?.role === 'BUSINESS' && order.account.user.assignedBusinessId !== reviewerId) {
        throw new UnauthorizedException('OTC order is not assigned to this business account');
      }
      if (order.account.cashBalance.lessThan(order.amount)) throw new BadRequestException('Insufficient cash balance');
      const balanceAfter = order.account.cashBalance.sub(order.amount);
      const reducedBuyingPower = order.account.buyingPower.sub(order.amount);
      const buyingPowerAfter = reducedBuyingPower.greaterThan(0)
        ? reducedBuyingPower
        : new Prisma.Decimal(0);
      await tx.account.update({ where: { id: order.accountId }, data: { cashBalance: balanceAfter, buyingPower: buyingPowerAfter } });
      const current = await tx.position.findUnique({ where: { accountId_instrumentId: { accountId: order.accountId, instrumentId: order.instrumentId } } });
      const newQuantity = (current?.quantity ?? 0) + order.quantity;
      const newAverage = current
        ? current.averagePrice.mul(current.quantity).add(order.price.mul(order.quantity)).div(newQuantity).toDecimalPlaces(4)
        : order.price;
      await tx.position.upsert({
        where: { accountId_instrumentId: { accountId: order.accountId, instrumentId: order.instrumentId } },
        create: { accountId: order.accountId, instrumentId: order.instrumentId, quantity: order.quantity, averagePrice: order.price },
        update: { quantity: newQuantity, averagePrice: newAverage },
      });
      const executionOrder = await tx.order.create({
        data: {
          clientOrderId: `OTC-${order.id}`,
          accountId: order.accountId,
          instrumentId: order.instrumentId,
          side: 'BUY',
          type: 'LIMIT',
          status: 'FILLED',
          quantity: order.quantity,
          filledQuantity: order.quantity,
          limitPrice: order.price,
          averageFillPrice: order.price,
          completedAt: new Date(),
        },
      });
      await tx.trade.create({
        data: {
          executionId: `OTC-EXEC-${order.id}`,
          orderId: executionOrder.id,
          accountId: order.accountId,
          instrumentId: order.instrumentId,
          quantity: order.quantity,
          price: order.price,
          grossAmount: order.amount,
          fees: new Prisma.Decimal(0),
          netAmount: order.amount,
        },
      });
      await tx.accountTransaction.create({ data: { accountId: order.accountId, type: 'OTC_SETTLEMENT', status: 'COMPLETED', amount: order.amount.negated(), balanceBefore: order.account.cashBalance, balanceAfter, referenceId: order.id, note: 'OTC purchase approved and settled' } });
      const approved = await tx.otcOrder.update({ where: { id: order.id }, data: { status: 'APPROVED', reviewedById: reviewerId, reviewedAt: new Date() }, include: { instrument: true } });
      await tx.notification.create({ data: { userId: order.account.user.id, type: 'OTC', title: 'OTC order approved', body: `${approved.instrument.symbol} has been settled and added to your holdings.`, referenceId: order.id } });
      return approved;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async reject(reviewerId: string, orderId: string, note?: string) {
    const existing = await this.prisma.otcOrder.findUnique({ where: { id: orderId }, include: { account: true, instrument: true } });
    const result = await this.prisma.otcOrder.updateMany({ where: { id: orderId, status: 'PENDING' }, data: { status: 'REJECTED', reviewedById: reviewerId, reviewedAt: new Date(), reviewNote: note?.trim() || null } });
    if (!result.count) throw new BadRequestException('OTC order not found or already reviewed');
    if (existing) {
      await this.prisma.notification.create({ data: { userId: existing.account.userId, type: 'OTC', title: 'OTC order rejected', body: `${existing.instrument.symbol} was not approved.${note ? ` ${note}` : ''}`, referenceId: orderId } });
    }
    return this.prisma.otcOrder.findUnique({ where: { id: orderId }, include: { instrument: true } });
  }
}
