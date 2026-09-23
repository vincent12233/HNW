import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { AppContentModule } from '../generated/prisma/enums';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { APP_CONTENT_DEFAULTS } from './app-content.defaults';
import { isAdminOnlySupportKey } from './app-content.visibility';

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

export type AppContentActor = {
  userId: string;
  role: string;
};

/** Accept a bare URL or a full <script src="..."> snippet from SaleSmartly. */
export function normalizeSaleSmartlyScriptUrl(raw: string): string {
  const text = String(raw ?? '').trim();
  if (!text) return '';
  const srcMatch = text.match(/src\s*=\s*["']([^"']+)["']/i);
  if (srcMatch?.[1]) return srcMatch[1].trim();
  return text;
}

const ALLOWED_LOCALES = new Set(['en', 'hi', 'zh']);

@Injectable()
export class AppContentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

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
      where: {
        isActive: true,
        // Desk-only SUPPORT keys stay out of the public client bundle.
        NOT: {
          module: AppContentModule.SUPPORT,
          key: { in: [...ADMIN_ONLY_SUPPORT_KEYS_LIST] },
        },
      },
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
        (latest, row) => (row.updatedAt > latest ? row.updatedAt : latest),
        new Date(0),
      ),
    };
  }

  /**
   * Desk config for support console (tags / quick replies).
   * Authenticated ADMIN or SUPPORT only — never via public GET.
   */
  async getSupportDeskContent(locale = 'zh') {
    await this.ensureDefaults();
    const wanted =
      String(locale || 'zh')
        .trim()
        .toLowerCase() || 'zh';
    const rows = await this.prisma.appContentEntry.findMany({
      where: {
        module: AppContentModule.SUPPORT,
        key: { in: [...ADMIN_ONLY_SUPPORT_KEYS_LIST] },
        isActive: true,
        locale: { in: [wanted, 'zh', 'en'] },
      },
      orderBy: [{ sortOrder: 'asc' }, { key: 'asc' }],
    });
    const picked = this.pickLocale(rows, wanted);
    return {
      locale: picked.localeUsed,
      support: this.moduleMap(picked.rows, AppContentModule.SUPPORT, {
        includeAdminOnlySupportKeys: true,
      }),
    };
  }

  async listAdmin(module?: string) {
    await this.ensureDefaults();
    return this.prisma.appContentEntry.findMany({
      where: module ? { module: this.parseModule(module) } : undefined,
      orderBy: [{ module: 'asc' }, { sortOrder: 'asc' }, { key: 'asc' }],
    });
  }

  async listHistory(id: string) {
    const entry = await this.prisma.appContentEntry.findUnique({ where: { id } });
    if (!entry) throw new NotFoundException('Content entry not found');
    return this.prisma.auditLog.findMany({
      where: { resource: 'app_content', resourceId: id },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: 50,
      select: {
        id: true,
        action: true,
        createdAt: true,
        metadata: true,
        actor: { select: { fullName: true, role: true } },
      },
    });
  }

  async restoreEntry(id: string, revisionId: string, expectedUpdatedAt: string, actor: AppContentActor) {
    if (typeof revisionId !== 'string' || !revisionId.trim()) {
      throw new BadRequestException('Revision ID is required');
    }
    const expected = new Date(expectedUpdatedAt);
    if (!Number.isFinite(expected.getTime())) throw new BadRequestException('Valid expectedUpdatedAt is required');
    const revision = await this.prisma.auditLog.findFirst({
      where: { id: revisionId, resource: 'app_content', resourceId: id },
    });
    const data = revision?.metadata;
    const snapshot = data && typeof data === 'object' && !Array.isArray(data)
      ? (data as Record<string, unknown>).after : null;
    if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot) ||
        typeof (snapshot as Record<string, unknown>).body !== 'string') {
      throw new BadRequestException('Revision cannot be restored');
    }
    const prior = snapshot as Record<string, unknown>;
    if (typeof prior.title !== 'string' && prior.title !== null ||
        typeof prior.isActive !== 'boolean' ||
        typeof prior.sortOrder !== 'number' || !Number.isFinite(prior.sortOrder) ||
        (prior.body as string).length > 200_000) {
      throw new BadRequestException('Revision snapshot is invalid');
    }
    const result = await this.prisma.$transaction(async (tx) => {
      const current = await tx.appContentEntry.findUnique({ where: { id } });
      if (!current) throw new NotFoundException('Content entry not found');
      if (current.updatedAt.getTime() !== expected.getTime()) {
        throw new ConflictException('Content changed since history was opened; reload and try again');
      }
      if (current.module === AppContentModule.SUPPORT && current.key === 'salesmartly_script_url') {
        throw new BadRequestException('Restore the shared support URL through the editor');
      }
      const updated = await tx.appContentEntry.updateMany({
        where: { id, updatedAt: expected },
        data: {
          body: prior.body as string,
          title: prior.title as string | null,
          isActive: prior.isActive as boolean,
          sortOrder: prior.sortOrder as number,
          ...(Object.hasOwn(prior, 'metadata') ? {
            metadata: prior.metadata === null ? Prisma.JsonNull : prior.metadata as Prisma.InputJsonValue,
          } : {}),
        },
      });
      if (updated.count !== 1) throw new ConflictException('Content changed; reload and try again');
      const restored = await tx.appContentEntry.findUniqueOrThrow({ where: { id } });
      await this.audit.createLog({
        actorId: actor.userId,
        action: 'APP_CONTENT_RESTORE',
        resource: 'app_content',
        resourceId: id,
        description: `Restored ${current.module}/${current.key}/${current.locale}`,
        metadata: {
          operatorRole: actor.role,
          revisionId,
          module: current.module,
          key: current.key,
          locale: current.locale,
          before: this.snapshot(current),
          after: this.snapshot(restored),
        },
      }, tx);
      return restored;
    });
    return result;
  }

  private snapshot(row: { title: string | null; body: string; metadata?: Prisma.JsonValue | null; isActive: boolean; sortOrder: number }) {
    return { title: row.title, body: row.body, metadata: row.metadata ?? null, isActive: row.isActive, sortOrder: row.sortOrder };
  }

  async upsertEntry(body: AppContentUpsertInput, actor?: AppContentActor) {
    const module = this.parseModule(String(body.module));
    const key = String(body.key || '').trim();
    const locale = this.parseLocale(body.locale);
    if (!key) throw new BadRequestException('Content key is required');
    if (body.body == null)
      throw new BadRequestException('Content body is required');
    if (key.length > 128) {
      throw new BadRequestException('Content key is too long');
    }
    const rawBody = String(body.body);
    if (rawBody.length > 200_000) {
      throw new BadRequestException('Content body is too long');
    }

    const normalizedBody =
      module === AppContentModule.SUPPORT && key === 'salesmartly_script_url'
        ? normalizeSaleSmartlyScriptUrl(rawBody)
        : rawBody;

    const before = await this.prisma.appContentEntry.findUnique({
      where: { module_key_locale: { module, key, locale } },
    });

    const createData = {
      module,
      key,
      title: body.title?.trim() || null,
      body: normalizedBody,
      metadata: body.metadata ?? Prisma.JsonNull,
      isActive: body.isActive ?? true,
      sortOrder: Number(body.sortOrder ?? 0),
      locale,
    };

    const result = await this.prisma.appContentEntry.upsert({
      where: {
        module_key_locale: { module, key, locale },
      },
      create: createData,
      update: {
        title:
          body.title === undefined ? undefined : body.title?.trim() || null,
        body: normalizedBody,
        metadata:
          body.metadata === undefined
            ? undefined
            : (body.metadata ?? Prisma.JsonNull),
        // Preserve existing isActive / sortOrder when omitted (Admin body edits).
        isActive: body.isActive === undefined ? undefined : body.isActive,
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
            module,
            key,
            title: createData.title,
            body: normalizedBody,
            metadata: createData.metadata,
            isActive: createData.isActive,
            sortOrder: createData.sortOrder,
            locale: otherLocale,
          },
          update: {
            body: normalizedBody,
            // Do not force isActive on the mirrored locale.
          },
        });
      }
    }

    if (actor) {
      await this.audit.createLog({
        actorId: actor.userId,
        action: before ? 'APP_CONTENT_UPDATE' : 'APP_CONTENT_CREATE',
        resource: 'app_content',
        resourceId: result.id,
        description: `${before ? 'Updated' : 'Created'} ${module}/${key}/${locale}`,
        metadata: {
          operatorRole: actor.role,
          module,
          key,
          locale,
          before: before ? this.snapshot(before) : null,
          after: this.snapshot(result),
        },
      });
    }

    return result;
  }

  async bulkUpsert(entries: AppContentUpsertInput[], actor?: AppContentActor) {
    if (!Array.isArray(entries) || entries.length === 0) {
      throw new BadRequestException('At least one content entry is required');
    }
    const results = [];
    for (const entry of entries) {
      results.push(await this.upsertEntry(entry, actor));
    }
    return results;
  }

  async deleteEntry(id: string, actor?: AppContentActor) {
    const existing = await this.prisma.appContentEntry.findUnique({
      where: { id },
    });
    if (!existing) {
      throw new NotFoundException('Content entry not found');
    }
    await this.prisma.appContentEntry.delete({ where: { id } });
    if (actor) {
      await this.audit.createLog({
        actorId: actor.userId,
        action: 'APP_CONTENT_DELETE',
        resource: 'app_content',
        resourceId: id,
        description: `Deleted ${existing.module}/${existing.key}/${existing.locale}`,
        metadata: {
          operatorRole: actor.role,
          module: existing.module,
          key: existing.key,
          locale: existing.locale,
          before: this.snapshot(existing),
          after: null,
        },
      });
    }
    return { ok: true };
  }

  async getDepositRejectMessage(locale = 'en') {
    const wanted =
      String(locale || 'en')
        .trim()
        .toLowerCase() || 'en';
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

  private parseModule(value: string): AppContentModule {
    const normalized = String(value || '')
      .trim()
      .toUpperCase();
    if (
      !Object.values(AppContentModule).includes(normalized as AppContentModule)
    ) {
      throw new BadRequestException('Invalid content module');
    }
    return normalized as AppContentModule;
  }

  private parseLocale(value?: string | null): string {
    const locale =
      String(value || 'en')
        .trim()
        .toLowerCase() || 'en';
    if (!ALLOWED_LOCALES.has(locale)) {
      throw new BadRequestException('Invalid content locale');
    }
    return locale;
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
    options?: { includeAdminOnlySupportKeys?: boolean },
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
      if (
        !options?.includeAdminOnlySupportKeys &&
        module === AppContentModule.SUPPORT &&
        isAdminOnlySupportKey(row.key)
      ) {
        continue;
      }
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

  /**
   * Public / desk locale pick: requested locale → en only.
   * Does not fall through to arbitrary locales (avoids leaking zh desk copy).
   * Keys with neither requested nor en content are omitted.
   */
  private pickLocale<
    T extends {
      key: string;
      module: AppContentModule;
      locale: string;
      body?: string | null;
    },
  >(rows: T[], locale: string) {
    const wanted =
      String(locale || 'en')
        .trim()
        .toLowerCase() || 'en';
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
      const chosen =
        preferredFilled ?? englishFilled ?? preferredAny ?? englishAny;
      if (chosen) picked.push(chosen);
    }
    return { localeUsed: wanted, rows: picked };
  }
}

const ADMIN_ONLY_SUPPORT_KEYS_LIST = [
  'tags',
  'quick_reply.deposit',
  'quick_reply.withdrawal',
  'quick_reply.kyc',
  'quick_reply.general',
] as const;
