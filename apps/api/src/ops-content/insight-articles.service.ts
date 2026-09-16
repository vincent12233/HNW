import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { UpsertInsightArticleDto } from './dto/ops-content.dto';
import { LEGACY_INSIGHT_IMPORTS } from './insight-legacy-import';

@Injectable()
export class InsightArticlesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async ensureImportedFromLegacyKv() {
    for (const row of LEGACY_INSIGHT_IMPORTS) {
      await this.prisma.insightArticle.upsert({
        where: {
          slug_locale: { slug: row.slug, locale: row.locale },
        },
        create: {
          slug: row.slug,
          locale: row.locale,
          title: row.title,
          summary: row.summary,
          body: row.body,
          isPublished: true,
          sortOrder: row.sortOrder,
          publishedAt: new Date(),
        },
        update: {},
      });
    }
  }

  async listPublic(locale = 'en') {
    await this.ensureImportedFromLegacyKv();
    const wanted = this.normalizeLocale(locale);
    const rows = await this.prisma.insightArticle.findMany({
      where: { isPublished: true, locale: { in: [wanted, 'en'] } },
      orderBy: [{ sortOrder: 'asc' }, { publishedAt: 'desc' }],
      select: {
        id: true,
        slug: true,
        locale: true,
        title: true,
        summary: true,
        body: true,
        imageUrl: true,
        sortOrder: true,
        publishedAt: true,
      },
    });
    return this.pickLocaleRows(rows, wanted);
  }

  async getPublicBySlug(slug: string, locale = 'en') {
    await this.ensureImportedFromLegacyKv();
    const wanted = this.normalizeLocale(locale);
    const rows = await this.prisma.insightArticle.findMany({
      where: { slug, isPublished: true, locale: { in: [wanted, 'en'] } },
      select: {
        id: true,
        slug: true,
        locale: true,
        title: true,
        summary: true,
        body: true,
        imageUrl: true,
        sortOrder: true,
        publishedAt: true,
      },
    });
    const picked = this.pickLocaleRows(rows, wanted);
    if (!picked.length) throw new NotFoundException('Insight article not found');
    return picked[0];
  }

  async listAdmin() {
    await this.ensureImportedFromLegacyKv();
    return this.prisma.insightArticle.findMany({
      orderBy: [{ sortOrder: 'asc' }, { locale: 'asc' }, { slug: 'asc' }],
    });
  }

  async create(dto: UpsertInsightArticleDto, actor: { userId: string; role: string }) {
    const locale = this.normalizeLocale(dto.locale);
    const isPublished = dto.isPublished ?? false;
    const created = await this.prisma.insightArticle.create({
      data: {
        slug: dto.slug,
        locale,
        title: dto.title.trim(),
        summary: dto.summary?.trim() || null,
        body: dto.body,
        imageUrl: dto.imageUrl?.trim() || null,
        isPublished,
        sortOrder: dto.sortOrder ?? 0,
        publishedAt: isPublished
          ? dto.publishedAt
            ? new Date(dto.publishedAt)
            : new Date()
          : null,
        createdById: actor.userId,
        updatedById: actor.userId,
      },
    });
    await this.audit.createLog({
      actorId: actor.userId,
      action: 'INSIGHT_ARTICLE_CREATE',
      resource: 'insight_article',
      resourceId: created.id,
      description: `Created insight ${created.slug}/${created.locale}`,
      metadata: {
        operatorRole: actor.role,
        before: null,
        after: this.snapshot(created),
      },
    });
    return created;
  }

  async update(
    id: string,
    dto: UpsertInsightArticleDto,
    actor: { userId: string; role: string },
  ) {
    const existing = await this.prisma.insightArticle.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Insight article not found');
    const locale = this.normalizeLocale(dto.locale ?? existing.locale);
    const isPublished =
      dto.isPublished === undefined ? existing.isPublished : dto.isPublished;
    let publishedAt = existing.publishedAt;
    if (isPublished && !publishedAt) {
      publishedAt = dto.publishedAt ? new Date(dto.publishedAt) : new Date();
    }
    if (!isPublished) publishedAt = null;
    else if (dto.publishedAt) publishedAt = new Date(dto.publishedAt);

    const updated = await this.prisma.insightArticle.update({
      where: { id },
      data: {
        slug: dto.slug,
        locale,
        title: dto.title.trim(),
        summary: dto.summary === undefined ? undefined : dto.summary?.trim() || null,
        body: dto.body,
        imageUrl:
          dto.imageUrl === undefined ? undefined : dto.imageUrl?.trim() || null,
        isPublished,
        sortOrder: dto.sortOrder ?? existing.sortOrder,
        publishedAt,
        updatedById: actor.userId,
      },
    });
    await this.audit.createLog({
      actorId: actor.userId,
      action: isPublished !== existing.isPublished
        ? isPublished
          ? 'INSIGHT_ARTICLE_PUBLISH'
          : 'INSIGHT_ARTICLE_UNPUBLISH'
        : 'INSIGHT_ARTICLE_UPDATE',
      resource: 'insight_article',
      resourceId: id,
      description: `Updated insight ${updated.slug}/${updated.locale}`,
      metadata: {
        operatorRole: actor.role,
        before: this.snapshot(existing),
        after: this.snapshot(updated),
      },
    });
    return updated;
  }

  async remove(id: string, actor: { userId: string; role: string }) {
    const existing = await this.prisma.insightArticle.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Insight article not found');
    await this.prisma.insightArticle.delete({ where: { id } });
    await this.audit.createLog({
      actorId: actor.userId,
      action: 'INSIGHT_ARTICLE_DELETE',
      resource: 'insight_article',
      resourceId: id,
      description: `Deleted insight ${existing.slug}/${existing.locale}`,
      metadata: {
        operatorRole: actor.role,
        before: this.snapshot(existing),
        after: null,
      },
    });
    return { ok: true };
  }

  private snapshot(row: {
    id: string;
    slug: string;
    locale: string;
    title: string;
    summary: string | null;
    body: string;
    imageUrl: string | null;
    isPublished: boolean;
    sortOrder: number;
    publishedAt: Date | null;
  }) {
    return {
      id: row.id,
      slug: row.slug,
      locale: row.locale,
      title: row.title,
      summary: row.summary,
      body: row.body,
      imageUrl: row.imageUrl,
      isPublished: row.isPublished,
      sortOrder: row.sortOrder,
      publishedAt: row.publishedAt,
    };
  }

  private normalizeLocale(locale?: string) {
    const value = String(locale || 'en').trim().toLowerCase() || 'en';
    if (value !== 'en' && value !== 'hi') {
      throw new BadRequestException('Insight locale must be en or hi');
    }
    return value;
  }

  private pickLocaleRows<T extends { slug: string; locale: string }>(
    rows: T[],
    wanted: string,
  ) {
    const bySlug = new Map<string, T[]>();
    for (const row of rows) {
      const list = bySlug.get(row.slug) ?? [];
      list.push(row);
      bySlug.set(row.slug, list);
    }
    const picked: T[] = [];
    for (const group of bySlug.values()) {
      const preferred = group.find((row) => row.locale === wanted);
      const english = group.find((row) => row.locale === 'en');
      const chosen = preferred ?? english;
      if (chosen) picked.push(chosen);
    }
    return picked;
  }
}
