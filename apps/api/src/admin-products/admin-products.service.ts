import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminProductsService {
  constructor(private readonly prisma: PrismaService) {}

  listWatchlist() {
    return this.prisma.adminWatchlistItem.findMany({ orderBy: { createdAt: 'desc' } });
  }

  createWatchlist(body: any) {
    this.require(body.symbol, '请输入股票代码');
    this.require(body.name, '请输入股票名称');
    return this.prisma.adminWatchlistItem.create({ data: this.watchlistData(body) });
  }

  updateWatchlist(id: string, body: any) {
    return this.updateOrThrow(() =>
      this.prisma.adminWatchlistItem.update({ where: { id }, data: this.watchlistData(body) }),
    );
  }

  updateWatchlistStatus(id: string, status: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminWatchlistItem.update({ where: { id }, data: { status } }),
    );
  }

  deleteWatchlist(id: string) {
    return this.updateOrThrow(() => this.prisma.adminWatchlistItem.delete({ where: { id } }));
  }

  listBlockTrades() {
    return this.prisma.adminBlockTrade.findMany({ orderBy: { createdAt: 'desc' } });
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
      this.prisma.adminBlockTrade.update({ where: { id }, data: this.blockTradeData(body) }),
    );
  }

  updateBlockTradeStatus(id: string, status: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminBlockTrade.update({ where: { id }, data: { status } }),
    );
  }

  deleteBlockTrade(id: string) {
    return this.updateOrThrow(() => this.prisma.adminBlockTrade.delete({ where: { id } }));
  }

  listFunds() {
    return this.prisma.adminFundProduct.findMany({ orderBy: { createdAt: 'desc' } });
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
      this.prisma.adminFundProduct.update({ where: { id }, data: this.fundData(body) }),
    );
  }

  updateFundStatus(id: string, status: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminFundProduct.update({ where: { id }, data: { status } }),
    );
  }

  deleteFund(id: string) {
    return this.updateOrThrow(() => this.prisma.adminFundProduct.delete({ where: { id } }));
  }

  listQuant() {
    return this.prisma.adminQuantStrategy.findMany({ orderBy: { createdAt: 'desc' } });
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
      this.prisma.adminQuantStrategy.update({ where: { id }, data: this.quantData(body) }),
    );
  }

  updateQuantStatus(id: string, status: string) {
    return this.updateOrThrow(() =>
      this.prisma.adminQuantStrategy.update({ where: { id }, data: { status } }),
    );
  }

  deleteQuant(id: string) {
    return this.updateOrThrow(() => this.prisma.adminQuantStrategy.delete({ where: { id } }));
  }

  private watchlistData(body: any) {
    return {
      symbol: String(body.symbol).trim().toUpperCase(),
      name: String(body.name).trim(),
      market: String(body.market || 'NSE').trim().toUpperCase(),
      category: String(body.category || '未分类').trim(),
      risk: String(body.risk || '中').trim(),
      reason: body.reason?.trim() || null,
    };
  }

  private blockTradeData(body: any) {
    return {
      symbol: String(body.symbol).trim().toUpperCase(),
      side: String(body.side || '买入').trim(),
      quantity: Number(body.quantity),
      price: new Prisma.Decimal(body.price),
      minTicket: new Prisma.Decimal(body.minTicket),
      note: body.note?.trim() || null,
    };
  }

  private fundData(body: any) {
    return {
      code: String(body.code).trim().toUpperCase(),
      name: String(body.name).trim(),
      type: String(body.type || '股票型').trim(),
      nav: new Prisma.Decimal(body.nav),
      minSubscribe: new Prisma.Decimal(body.minSubscribe),
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
      annualReturn: new Prisma.Decimal(body.annualReturn),
      maxDrawdown: new Prisma.Decimal(body.maxDrawdown),
    };
  }

  private require(value: unknown, message: string) {
    if (!String(value ?? '').trim()) {
      throw new BadRequestException(message);
    }
  }

  private async updateOrThrow<T>(operation: () => Promise<T>) {
    try {
      return await operation();
    } catch {
      throw new NotFoundException('未找到记录');
    }
  }
}
