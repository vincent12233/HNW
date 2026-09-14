import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { AppContentModule } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

export type AppContentUpsertInput = {
  module: AppContentModule | string;
  key: string;
  title?: string | null;
  body: string;
  locale?: string;
  metadata?: Prisma.InputJsonValue | null;
  isActive?: boolean;
  sortOrder?: number;
};

export type DepositAccountInput = {
  label: string;
  method: string;
  accountName?: string | null;
  bankName?: string | null;
  accountNumber?: string | null;
  ifsc?: string | null;
  upiId?: string | null;
  notes?: string | null;
  isActive?: boolean;
  sortOrder?: number;
};

@Injectable()
export class AppContentService {
  constructor(private readonly prisma: PrismaService) {}

  async getPublicBundle(locale = 'en') {
    const [entries, accounts] = await Promise.all([
      this.prisma.appContentEntry.findMany({
        where: { isActive: true },
        orderBy: [{ module: 'asc' }, { sortOrder: 'asc' }, { key: 'asc' }],
      }),
      this.prisma.depositReceivingAccount.findMany({
        where: { isActive: true },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      }),
    ]);

    const preferred = this.pickLocale(entries, locale);
    return {
      locale: preferred.localeUsed,
      home: this.moduleMap(preferred.rows, AppContentModule.HOME),
      deposit: {
        ...this.moduleMap(preferred.rows, AppContentModule.DEPOSIT),
        receivingAccounts: accounts.map((account) => ({
          id: account.id,
          label: account.label,
          method: account.method,
          accountName: account.accountName,
          bankName: account.bankName,
          accountNumber: account.accountNumber,
          ifsc: account.ifsc,
          upiId: account.upiId,
          notes: account.notes,
          sortOrder: account.sortOrder,
        })),
      },
      support: this.moduleMap(preferred.rows, AppContentModule.SUPPORT),
      trading: this.moduleMap(preferred.rows, AppContentModule.TRADING),
      updatedAt: preferred.rows.reduce(
        (latest, row) =>
          row.updatedAt > latest ? row.updatedAt : latest,
        new Date(0),
      ),
    };
  }

  async listAdmin(module?: string) {
    return this.prisma.appContentEntry.findMany({
      where: module
        ? { module: this.parseModule(module) }
        : undefined,
      orderBy: [{ module: 'asc' }, { sortOrder: 'asc' }, { key: 'asc' }],
    });
  }

  async upsertEntry(body: AppContentUpsertInput) {
    const module = this.parseModule(body.module);
    const key = String(body.key || '').trim();
    const locale = String(body.locale || 'en').trim().toLowerCase() || 'en';
    if (!key) throw new BadRequestException('Content key is required');
    if (body.body == null) throw new BadRequestException('Content body is required');

    return this.prisma.appContentEntry.upsert({
      where: {
        module_key_locale: { module, key, locale },
      },
      create: {
        module,
        key,
        title: body.title?.trim() || null,
        body: String(body.body),
        locale,
        metadata: body.metadata ?? Prisma.JsonNull,
        isActive: body.isActive ?? true,
        sortOrder: Number(body.sortOrder ?? 0),
      },
      update: {
        title: body.title === undefined ? undefined : body.title?.trim() || null,
        body: String(body.body),
        metadata:
          body.metadata === undefined
            ? undefined
            : body.metadata ?? Prisma.JsonNull,
        isActive: body.isActive,
        sortOrder:
          body.sortOrder === undefined ? undefined : Number(body.sortOrder),
      },
    });
  }

  async bulkUpsert(entries: AppContentUpsertInput[]) {
    if (!Array.isArray(entries) || entries.length === 0) {
      throw new BadRequestException('At least one content entry is required');
    }
    const results = [];
    for (const entry of entries) {
      results.push(await this.upsertEntry(entry));
    }
    return results;
  }

  async deleteEntry(id: string) {
    try {
      await this.prisma.appContentEntry.delete({ where: { id } });
      return { ok: true };
    } catch {
      throw new NotFoundException('Content entry not found');
    }
  }

  listDepositAccounts(includeInactive = false) {
    return this.prisma.depositReceivingAccount.findMany({
      where: includeInactive ? undefined : { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    });
  }

  createDepositAccount(body: DepositAccountInput) {
    const data = this.depositAccountData(body);
    return this.prisma.depositReceivingAccount.create({ data });
  }

  async updateDepositAccount(id: string, body: DepositAccountInput) {
    try {
      return await this.prisma.depositReceivingAccount.update({
        where: { id },
        data: this.depositAccountData(body),
      });
    } catch {
      throw new NotFoundException('Deposit account not found');
    }
  }

  async setDepositAccountStatus(id: string, isActive: boolean) {
    try {
      return await this.prisma.depositReceivingAccount.update({
        where: { id },
        data: { isActive: Boolean(isActive) },
      });
    } catch {
      throw new NotFoundException('Deposit account not found');
    }
  }

  async deleteDepositAccount(id: string) {
    try {
      await this.prisma.depositReceivingAccount.delete({ where: { id } });
      return { ok: true };
    } catch {
      throw new NotFoundException('Deposit account not found');
    }
  }

  async getDepositRejectMessage() {
    const row = await this.prisma.appContentEntry.findFirst({
      where: {
        module: AppContentModule.DEPOSIT,
        key: 'api_reject_message',
        locale: 'en',
        isActive: true,
      },
    });
    return (
      row?.body?.trim() ||
      'Please contact online support for deposit instructions. Finance will credit your account after payment is confirmed.'
    );
  }

  private depositAccountData(body: DepositAccountInput) {
    const label = String(body.label || '').trim();
    const method = String(body.method || '').trim().toUpperCase();
    if (!label) throw new BadRequestException('Account label is required');
    if (!['BANK', 'UPI', 'OTHER'].includes(method)) {
      throw new BadRequestException('Method must be BANK, UPI or OTHER');
    }
    return {
      label,
      method,
      accountName: body.accountName?.trim() || null,
      bankName: body.bankName?.trim() || null,
      accountNumber: body.accountNumber?.trim() || null,
      ifsc: body.ifsc?.trim()?.toUpperCase() || null,
      upiId: body.upiId?.trim() || null,
      notes: body.notes?.trim() || null,
      isActive: body.isActive ?? true,
      sortOrder: Number(body.sortOrder ?? 0),
    };
  }

  private parseModule(value: AppContentModule | string): AppContentModule {
    const normalized = String(value || '')
      .trim()
      .toUpperCase();
    if (
      !Object.values(AppContentModule).includes(
        normalized as AppContentModule,
      )
    ) {
      throw new BadRequestException('Invalid content module');
    }
    return normalized as AppContentModule;
  }

  private moduleMap(
    rows: Array<{
      module: AppContentModule;
      key: string;
      title: string | null;
      body: string;
      locale: string;
      metadata: Prisma.JsonValue | null;
      sortOrder: number;
    }>,
    module: AppContentModule,
  ) {
    const map: Record<
      string,
      {
        title: string | null;
        body: string;
        locale: string;
        metadata: Prisma.JsonValue | null;
        sortOrder: number;
      }
    > = {};
    for (const row of rows) {
      if (row.module !== module) continue;
      map[row.key] = {
        title: row.title,
        body: row.body,
        locale: row.locale,
        metadata: row.metadata,
        sortOrder: row.sortOrder,
      };
    }
    return map;
  }

  private pickLocale<
    T extends { key: string; module: AppContentModule; locale: string },
  >(rows: T[], locale: string) {
    const wanted = String(locale || 'en').trim().toLowerCase() || 'en';
    const byKey = new Map<string, T>();
    for (const row of rows) {
      const mapKey = `${row.module}:${row.key}`;
      const existing = byKey.get(mapKey);
      if (!existing) {
        byKey.set(mapKey, row);
        continue;
      }
      if (row.locale === wanted) {
        byKey.set(mapKey, row);
      } else if (existing.locale !== wanted && row.locale === 'en') {
        byKey.set(mapKey, row);
      }
    }
    return { localeUsed: wanted, rows: [...byKey.values()] };
  }
}
