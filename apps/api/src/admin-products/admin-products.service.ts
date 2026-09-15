import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { Exchange, InstrumentType } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

type ProductBody = Record<string, unknown>;

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

  async createWatchlist(body: ProductBody) {
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

  async updateWatchlist(id: string, body: ProductBody) {
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

  createBlockTrade(body: ProductBody) {
    this.require(body.symbol, '请输入标的代码');
    return this.prisma.adminBlockTrade.create({
      data: {
        ...this.blockTradeData(body),
        orderNo: `BT${Date.now()}`,
        status: '审核中',
      },
    });
  }

  updateBlockTrade(id: string, body: ProductBody) {
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

  createFund(body: ProductBody) {
    this.require(body.code, '请输入基金代码');
    this.require(body.name, '请输入基金名称');
    return this.prisma.adminFundProduct.create({
      data: {
        ...this.fundData(body),
        status: '开放申购',
      },
    });
  }

  updateFund(id: string, body: ProductBody) {
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

  createQuant(body: ProductBody) {
    this.require(body.code, '请输入策略编号');
    this.require(body.name, '请输入策略名称');
    return this.prisma.adminQuantStrategy.create({
      data: {
        ...this.quantData(body),
        status: '观察中',
      },
    });
  }

  updateQuant(id: string, body: ProductBody) {
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

  private watchlistData(body: ProductBody) {
    const direction = this.text(body.direction, 'UP').toUpperCase();
    if (!['UP', 'DOWN'].includes(direction))
      throw new BadRequestException('Direction must be UP or DOWN');
    const expectedReturn = this.moneyValue(
      body.expectedReturn,
      'Expected return',
      2,
      { optional: true, max: 100 },
    );
    const market = this.text(body.market, 'NSE').toUpperCase();
    if (!['NSE', 'BSE'].includes(market)) {
      throw new BadRequestException('Market must be NSE or BSE');
    }
    return {
      symbol: this.text(body.symbol).toUpperCase(),
      name: this.text(body.name),
      market,
      category: this.text(body.category, '未分类'),
      risk: this.text(body.risk, '中'),
      reason: this.optionalText(body.reason),
      direction,
      expectedReturn,
    };
  }

  private blockTradeData(body: ProductBody) {
    return {
      symbol: this.text(body.symbol).toUpperCase(),
      side: this.text(body.side, '买入'),
      quantity: this.positiveInteger(body.quantity, 'Quantity'),
      price: this.moneyValue(body.price, 'Price', 4)!,
      minTicket: this.moneyValue(body.minTicket, 'Minimum ticket', 2)!,
      note: this.optionalText(body.note),
    };
  }

  private fundData(body: ProductBody) {
    return {
      code: this.text(body.code).toUpperCase(),
      name: this.text(body.name),
      type: this.text(body.type, '股票型'),
      nav: this.moneyValue(body.nav, 'NAV', 4)!,
      minSubscribe: this.moneyValue(
        body.minSubscribe,
        'Minimum subscription',
        2,
      )!,
      risk: this.text(body.risk, '中'),
      manager: this.optionalText(body.manager),
    };
  }

  private quantData(body: ProductBody) {
    return {
      code: this.text(body.code).toUpperCase(),
      name: this.text(body.name),
      market: this.text(body.market, 'NSE'),
      risk: this.text(body.risk, '中'),
      annualReturn: this.moneyValue(body.annualReturn, 'Annual return', 2, {
        allowZero: true,
      })!,
      maxDrawdown: this.moneyValue(body.maxDrawdown, 'Max drawdown', 2, {
        allowZero: true,
        max: 100,
      })!,
    };
  }

  private text(value: unknown, fallback = ''): string {
    if (value == null || value === '') return fallback;
    if (typeof value === 'string') return value.trim() || fallback;
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value).trim() || fallback;
    }
    return fallback;
  }

  private optionalText(value: unknown): string | null {
    if (value == null) return null;
    if (typeof value === 'string') return value.trim() || null;
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value).trim() || null;
    }
    return null;
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
    let text: string;
    if (typeof value === 'number' && Number.isFinite(value)) {
      text = value.toFixed(maxDecimals);
    } else if (typeof value === 'string') {
      text = value.trim();
    } else if (typeof value === 'boolean') {
      text = String(value);
    } else {
      throw new BadRequestException(
        `${label} must be a monetary value with up to ${maxDecimals} decimals`,
      );
    }
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
    let text: string;
    if (typeof value === 'number' && Number.isFinite(value)) {
      text = String(Math.trunc(value));
    } else if (typeof value === 'string') {
      text = value.trim();
    } else {
      throw new BadRequestException(`${label} must be a positive whole number`);
    }
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
    if (typeof value === 'string') {
      if (!value.trim()) throw new BadRequestException(message);
      return;
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      if (!String(value).trim()) throw new BadRequestException(message);
      return;
    }
    throw new BadRequestException(message);
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
