import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { Exchange, InstrumentType } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminProductsService {
  constructor(private readonly prisma: PrismaService) {}

  listWatchlist(role?: string) {
    return this.prisma.adminWatchlistItem.findMany({
      where:
        role === 'ADMIN' ? undefined : { status: { in: ['ACTIVE', '展示中'] } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createWatchlist(body: any) {
    this.require(body.symbol, '请输入股票代码');
    this.require(body.name, '请输入股票名称');
    const data = this.watchlistData(body);
    const duplicate = await this.prisma.adminWatchlistItem.findFirst({
      where: { symbol: data.symbol, market: data.market },
    });
    if (duplicate)
      throw new ConflictException('This Inst. stock is already listed');
    const item = await this.prisma.adminWatchlistItem.create({ data });
    await this.markInstitutionalInstrument(data.symbol, data.market, data.name);
    return item;
  }

  async updateWatchlist(id: string, body: any) {
    const item = await this.updateOrThrow(() =>
      this.prisma.adminWatchlistItem.update({
        where: { id },
        data: this.watchlistData(body),
      }),
    );
    await this.markInstitutionalInstrument(item.symbol, item.market, item.name);
    return item;
  }

  updateWatchlistStatus(id: string, status: string) {
    if (!['ACTIVE', 'PAUSED'].includes(status))
      throw new BadRequestException('Status must be ACTIVE or PAUSED');
    return this.updateOrThrow(() =>
      this.prisma.adminWatchlistItem.update({
        where: { id },
        data: { status },
      }),
    );
  }

  deleteWatchlist(id: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminWatchlistItem.delete({ where: { id } }),
    );
  }

  listBlockTrades(role?: string) {
    return this.prisma.adminBlockTrade.findMany({
      where: role === 'ADMIN' ? undefined : { status: { not: '已下架' } },
      orderBy: { createdAt: 'desc' },
    });
  }

  createBlockTrade(body: any) {
    this.require(body.symbol, '请输入标的代码');
    return this.prisma.adminBlockTrade.create({
      data: {
        ...this.blockTradeData(body),
        orderNo: `BT${Date.now()}`,
        status: '审核中',
      },
    });
  }

  updateBlockTrade(id: string, body: any) {
    return this.updateOrThrow(() =>
      this.prisma.adminBlockTrade.update({
        where: { id },
        data: this.blockTradeData(body),
      }),
    );
  }

  updateBlockTradeStatus(id: string, status: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminBlockTrade.update({ where: { id }, data: { status } }),
    );
  }

  deleteBlockTrade(id: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminBlockTrade.delete({ where: { id } }),
    );
  }

  listFunds() {
    return this.prisma.adminFundProduct.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  createFund(body: any) {
    this.require(body.code, '请输入基金代码');
    this.require(body.name, '请输入基金名称');
    return this.prisma.adminFundProduct.create({
      data: {
        ...this.fundData(body),
        status: '开放申购',
      },
    });
  }

  updateFund(id: string, body: any) {
    return this.updateOrThrow(() =>
      this.prisma.adminFundProduct.update({
        where: { id },
        data: this.fundData(body),
      }),
    );
  }

  updateFundStatus(id: string, status: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminFundProduct.update({ where: { id }, data: { status } }),
    );
  }

  deleteFund(id: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminFundProduct.delete({ where: { id } }),
    );
  }

  listQuant() {
    return this.prisma.adminQuantStrategy.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  createQuant(body: any) {
    this.require(body.code, '请输入策略编号');
    this.require(body.name, '请输入策略名称');
    return this.prisma.adminQuantStrategy.create({
      data: {
        ...this.quantData(body),
        status: '观察中',
      },
    });
  }

  updateQuant(id: string, body: any) {
    return this.updateOrThrow(() =>
      this.prisma.adminQuantStrategy.update({
        where: { id },
        data: this.quantData(body),
      }),
    );
  }

  updateQuantStatus(id: string, status: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminQuantStrategy.update({
        where: { id },
        data: { status },
      }),
    );
  }

  deleteQuant(id: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminQuantStrategy.delete({ where: { id } }),
    );
  }

  private watchlistData(body: any) {
    const direction = String(body.direction || 'UP')
      .trim()
      .toUpperCase();
    if (!['UP', 'DOWN'].includes(direction))
      throw new BadRequestException('Direction must be UP or DOWN');
    const expectedReturn = this.moneyValue(
      body.expectedReturn,
      'Expected return',
      2,
      { optional: true, max: 100 },
    );
    const market = String(body.market || 'NSE')
      .trim()
      .toUpperCase();
    if (!['NSE', 'BSE'].includes(market)) {
      throw new BadRequestException('Market must be NSE or BSE');
    }
    return {
      symbol: String(body.symbol).trim().toUpperCase(),
      name: String(body.name).trim(),
      market,
      category: String(body.category || '未分类').trim(),
      risk: String(body.risk || '中').trim(),
      reason: body.reason?.trim() || null,
      direction,
      expectedReturn,
    };
  }

  private blockTradeData(body: any) {
    return {
      symbol: String(body.symbol).trim().toUpperCase(),
      side: String(body.side || '买入').trim(),
      quantity: this.positiveInteger(body.quantity, 'Quantity'),
      price: this.moneyValue(body.price, 'Price', 4)!,
      minTicket: this.moneyValue(body.minTicket, 'Minimum ticket', 2)!,
      note: body.note?.trim() || null,
    };
  }

  private fundData(body: any) {
    return {
      code: String(body.code).trim().toUpperCase(),
      name: String(body.name).trim(),
      type: String(body.type || '股票型').trim(),
      nav: this.moneyValue(body.nav, 'NAV', 4)!,
      minSubscribe: this.moneyValue(body.minSubscribe, 'Minimum subscription', 2)!,
      risk: String(body.risk || '中').trim(),
      manager: body.manager?.trim() || null,
    };
  }

  private quantData(body: any) {
    return {
      code: String(body.code).trim().toUpperCase(),
      name: String(body.name).trim(),
      market: String(body.market || 'NSE').trim(),
      risk: String(body.risk || '中').trim(),
      annualReturn: this.moneyValue(body.annualReturn, 'Annual return', 2, { allowZero: true })!,
      maxDrawdown: this.moneyValue(body.maxDrawdown, 'Max drawdown', 2, { allowZero: true, max: 100 })!,
    };
  }


  private moneyValue(
    value: unknown,
    label: string,
    maxDecimals: 2 | 4,
    options: { optional?: boolean; allowZero?: boolean; max?: number } = {},
  ): Prisma.Decimal | null {
    if (value == null || value === '') {
      if (options.optional) return null;
      throw new BadRequestException(`${label} is required`);
    }
    const text =
      typeof value === 'number' && Number.isFinite(value)
        ? value.toFixed(maxDecimals)
        : String(value).trim();
    const pattern =
      maxDecimals === 4
        ? /^(?:0|[1-9]\d*)(?:\.\d{1,4})?$/
        : /^(?:0|[1-9]\d*)(?:\.\d{1,2})?$/;
    if (!pattern.test(text)) {
      throw new BadRequestException(
        `${label} must be a monetary value with up to ${maxDecimals} decimals`,
      );
    }
    let decimal: Prisma.Decimal;
    try {
      decimal = new Prisma.Decimal(text);
    } catch {
      throw new BadRequestException(`${label} is invalid`);
    }
    if (!decimal.isFinite()) {
      throw new BadRequestException(`${label} is invalid`);
    }
    if (!options.allowZero && decimal.lte(0)) {
      throw new BadRequestException(`${label} must be greater than zero`);
    }
    if (options.allowZero && decimal.lt(0)) {
      throw new BadRequestException(`${label} cannot be negative`);
    }
    if (options.max != null && decimal.gt(options.max)) {
      throw new BadRequestException(`${label} exceeds the allowed maximum`);
    }
    return decimal;
  }

  private positiveInteger(value: unknown, label: string, max = 1_000_000_000) {
    const text =
      typeof value === 'number' && Number.isFinite(value)
        ? String(Math.trunc(value))
        : String(value ?? '').trim();
    if (!/^\d+$/.test(text)) {
      throw new BadRequestException(`${label} must be a positive whole number`);
    }
    const quantity = Number(text);
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > max) {
      throw new BadRequestException(`${label} must be a positive whole number`);
    }
    return quantity;
  }

  private require(value: unknown, message: string) {
    if (!String(value ?? '').trim()) {
      throw new BadRequestException(message);
    }
  }

  private async markInstitutionalInstrument(
    symbol: string,
    market: string,
    name: string,
  ) {
    const normalizedSymbol = symbol.trim().toUpperCase();
    const exchange =
      market.trim().toUpperCase() === 'BSE' ? Exchange.BSE : Exchange.NSE;
    await this.prisma.instrument.upsert({
      where: { exchange_symbol: { symbol: normalizedSymbol, exchange } },
      update: { name: name.trim(), category: 'INSTITUTIONAL', isActive: true },
      create: {
        symbol: normalizedSymbol,
        exchange,
        name: name.trim(),
        category: 'INSTITUTIONAL',
        type: InstrumentType.EQUITY,
        currency: 'INR',
        lotSize: 1,
        tickSize: '0.05',
        isActive: true,
      },
    });
  }

  private async updateOrThrow<T>(operation: () => Promise<T>) {
    try {
      return await operation();
    } catch {
      throw new NotFoundException('未找到记录');
    }
  }
}
