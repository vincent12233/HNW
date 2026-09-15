import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { AppContentModule } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { APP_CONTENT_DEFAULTS } from './app-content.defaults';

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

/** Accept a bare URL or a full <script src="..."> snippet from SaleSmartly. */
export function normalizeSaleSmartlyScriptUrl(raw: string): string {
  const text = String(raw ?? '').trim();
  if (!text) return '';
  const srcMatch = text.match(/src\s*=\s*["']([^"']+)["']/i);
  if (srcMatch?.[1]) return srcMatch[1].trim();
  return text;
}

@Injectable()
export class AppContentService {
  constructor(private readonly prisma: PrismaService) {}

  private ensureDefaultsPromise: Promise<void> | null = null;

  async ensureDefaults() {
    if (!this.ensureDefaultsPromise) {
      this.ensureDefaultsPromise = this.seedMissingDefaults().finally(() => {
        this.ensureDefaultsPromise = null;
      });
    }
    await this.ensureDefaultsPromise;
  }

  private async seedMissingDefaults() {
    for (const entry of APP_CONTENT_DEFAULTS) {
      const locale = entry.locale || 'en';
      const existing = await this.prisma.appContentEntry.findUnique({
        where: {
          module_key_locale: {
            module: entry.module,
            key: entry.key,
            locale,
          },
        },
      });
      if (existing) {
        // Backfill empty SaleSmartly URL once a default is configured.
        if (
          entry.module === AppContentModule.SUPPORT &&
          entry.key === 'salesmartly_script_url' &&
          String(entry.body ?? '').trim() &&
          !String(existing.body ?? '').trim()
        ) {
          await this.prisma.appContentEntry.update({
            where: { id: existing.id },
            data: { body: entry.body },
          });
        }
        continue;
      }
      await this.prisma.appContentEntry.create({
        data: {
          module: entry.module,
          key: entry.key,
          title: entry.title ?? null,
          body: entry.body,
          locale,
          isActive: entry.isActive ?? true,
          sortOrder: entry.sortOrder ?? 0,
        },
      });
    }
  }

  async getPublicBundle(locale = 'en') {
    await this.ensureDefaults();
    const entries = await this.prisma.appContentEntry.findMany({
      where: { isActive: true },
      orderBy: [{ module: 'asc' }, { sortOrder: 'asc' }, { key: 'asc' }],
    });

    const preferred = this.pickLocale(entries, locale);
    const support = this.applySaleSmartlyScriptFallback(
      this.moduleMap(preferred.rows, AppContentModule.SUPPORT),
    );
    return {
      locale: preferred.localeUsed,
      home: this.moduleMap(preferred.rows, AppContentModule.HOME),
      deposit: this.moduleMap(preferred.rows, AppContentModule.DEPOSIT),
      support,
      trading: this.moduleMap(preferred.rows, AppContentModule.TRADING),
      legal: this.moduleMap(preferred.rows, AppContentModule.LEGAL),
      about: this.moduleMap(preferred.rows, AppContentModule.ABOUT),
      insights: this.moduleMap(preferred.rows, AppContentModule.INSIGHTS),
      updatedAt: preferred.rows.reduce(
        (latest, row) =>
          row.updatedAt > latest ? row.updatedAt : latest,
        new Date(0),
      ),
    };
  }

  async listAdmin(module?: string) {
    await this.ensureDefaults();
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

    const normalizedBody =
      module === AppContentModule.SUPPORT && key === 'salesmartly_script_url'
        ? normalizeSaleSmartlyScriptUrl(String(body.body))
        : String(body.body);

    const data = {
      module,
      key,
      title: body.title?.trim() || null,
      body: normalizedBody,
      metadata: body.metadata ?? Prisma.JsonNull,
      isActive: body.isActive ?? true,
      sortOrder: Number(body.sortOrder ?? 0),
    };

    const result = await this.prisma.appContentEntry.upsert({
      where: {
        module_key_locale: { module, key, locale },
      },
      create: {
        ...data,
        locale,
      },
      update: {
        title: body.title === undefined ? undefined : body.title?.trim() || null,
        body: normalizedBody,
        metadata:
          body.metadata === undefined
            ? undefined
            : body.metadata ?? Prisma.JsonNull,
        isActive: body.isActive,
        sortOrder:
          body.sortOrder === undefined ? undefined : Number(body.sortOrder),
      },
    });

    // SaleSmartly script URL is locale-agnostic — keep en/hi in sync.
    if (
      module === AppContentModule.SUPPORT &&
      key === 'salesmartly_script_url'
    ) {
      for (const otherLocale of ['en', 'hi']) {
        if (otherLocale === locale) continue;
        await this.prisma.appContentEntry.upsert({
          where: {
            module_key_locale: { module, key, locale: otherLocale },
          },
          create: {
            ...data,
            locale: otherLocale,
          },
          update: {
            body: normalizedBody,
            isActive: body.isActive ?? true,
          },
        });
      }
    }

    return result;
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

  async getDepositRejectMessage(locale = 'en') {
    const wanted = String(locale || 'en').trim().toLowerCase() || 'en';
    const rows = await this.prisma.appContentEntry.findMany({
      where: {
        module: AppContentModule.DEPOSIT,
        key: 'api_reject_message',
        isActive: true,
        locale: { in: [wanted, 'en'] },
      },
    });
    const preferred =
      rows.find((row) => row.locale === wanted && row.body.trim()) ||
      rows.find((row) => row.locale === 'en' && row.body.trim()) ||
      rows[0];
    return (
      preferred?.body?.trim() ||
      'Please contact online support for deposit instructions. Finance will credit your account after payment is confirmed.'
    );
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

  /** Prefer CMS URL; fall back to SALESMARTLY_SCRIPT_URL for ops/deploy. */
  private applySaleSmartlyScriptFallback(
    support: Record<
      string,
      {
        title: string | null;
        body: string;
        locale: string;
        metadata: Prisma.JsonValue | null;
        sortOrder: number;
      }
    >,
  ) {
    const current = support.salesmartly_script_url;
    const cmsUrl = normalizeSaleSmartlyScriptUrl(String(current?.body ?? ''));
    if (cmsUrl) {
      support.salesmartly_script_url = {
        ...(current ?? {
          title: null,
          locale: 'en',
          metadata: null,
          sortOrder: 40,
        }),
        body: cmsUrl,
      };
      return support;
    }
    const envUrl = normalizeSaleSmartlyScriptUrl(
      String(process.env.SALESMARTLY_SCRIPT_URL ?? ''),
    );
    if (!envUrl) return support;
    support.salesmartly_script_url = {
      title: current?.title ?? null,
      body: envUrl,
      locale: current?.locale ?? 'en',
      metadata: current?.metadata ?? null,
      sortOrder: current?.sortOrder ?? 40,
    };
    return support;
  }

  private pickLocale<
    T extends {
      key: string;
      module: AppContentModule;
      locale: string;
      body?: string | null;
    },
  >(rows: T[], locale: string) {
    const wanted = String(locale || 'en').trim().toLowerCase() || 'en';
    const groups = new Map<string, T[]>();
    for (const row of rows) {
      const mapKey = `${row.module}:${row.key}`;
      const group = groups.get(mapKey);
      if (group) group.push(row);
      else groups.set(mapKey, [row]);
    }

    const picked: T[] = [];
    for (const group of groups.values()) {
      const hasBody = (row: T) => String(row.body ?? '').trim().length > 0;
      const preferredFilled = group.find(
        (row) => row.locale === wanted && hasBody(row),
      );
      const englishFilled = group.find(
        (row) => row.locale === 'en' && hasBody(row),
      );
      const preferredAny = group.find((row) => row.locale === wanted);
      const englishAny = group.find((row) => row.locale === 'en');
      picked.push(
        preferredFilled ??
          englishFilled ??
          preferredAny ??
          englishAny ??
          group[0],
      );
    }
    return { localeUsed: wanted, rows: picked };
  }
}
