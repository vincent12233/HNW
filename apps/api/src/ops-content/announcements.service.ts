import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AnnouncementType } from '../generated/prisma/enums';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { UpsertAnnouncementDto } from './dto/ops-content.dto';

@Injectable()
export class AnnouncementsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async listPublic(locale = 'en') {
    const wanted = this.normalizeLocale(locale);
    const now = new Date();
    const rows = await this.prisma.announcement.findMany({
      where: {
        isPublished: true,
        locale: { in: [wanted, 'en'] },
        AND: [
          { OR: [{ startsAt: null }, { startsAt: { lte: now } }] },
          { OR: [{ endsAt: null }, { endsAt: { gte: now } }] },
        ],
      },
      orderBy: [{ priority: 'desc' }, { sortOrder: 'asc' }, { createdAt: 'desc' }],
      select: {
        id: true,
        locale: true,
        title: true,
        body: true,
        type: true,
        priority: true,
        startsAt: true,
        endsAt: true,
        sortOrder: true,
      },
    });
    return this.pickLocaleRows(rows, wanted);
  }

  listAdmin() {
    return this.prisma.announcement.findMany({
      orderBy: [{ priority: 'desc' }, { sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  async create(
    dto: UpsertAnnouncementDto,
    actor: { userId: string; role: string },
  ) {
    this.assertSchedule(dto.startsAt, dto.endsAt);
    const created = await this.prisma.announcement.create({
      data: {
        locale: this.normalizeLocale(dto.locale),
        title: dto.title.trim(),
        body: dto.body,
        type: dto.type ?? AnnouncementType.GENERAL,
        isPublished: dto.isPublished ?? false,
        priority: dto.priority ?? 0,
        startsAt: dto.startsAt ? new Date(dto.startsAt) : null,
        endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
        sortOrder: dto.sortOrder ?? 0,
        createdById: actor.userId,
        updatedById: actor.userId,
      },
    });
    await this.audit.createLog({
      actorId: actor.userId,
      action: 'ANNOUNCEMENT_CREATE',
      resource: 'announcement',
      resourceId: created.id,
      description: `Created announcement ${created.title}`,
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
    dto: UpsertAnnouncementDto,
    actor: { userId: string; role: string },
  ) {
    const existing = await this.prisma.announcement.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Announcement not found');
    this.assertSchedule(
      dto.startsAt === undefined
        ? existing.startsAt?.toISOString()
        : dto.startsAt,
      dto.endsAt === undefined ? existing.endsAt?.toISOString() : dto.endsAt,
    );
    const isPublished =
      dto.isPublished === undefined ? existing.isPublished : dto.isPublished;
    const updated = await this.prisma.announcement.update({
      where: { id },
      data: {
        locale: this.normalizeLocale(dto.locale ?? existing.locale),
        title: dto.title.trim(),
        body: dto.body,
        type: dto.type ?? existing.type,
        isPublished,
        priority: dto.priority ?? existing.priority,
        startsAt:
          dto.startsAt === undefined
            ? undefined
            : dto.startsAt
              ? new Date(dto.startsAt)
              : null,
        endsAt:
          dto.endsAt === undefined
            ? undefined
            : dto.endsAt
              ? new Date(dto.endsAt)
              : null,
        sortOrder: dto.sortOrder ?? existing.sortOrder,
        updatedById: actor.userId,
      },
    });
    await this.audit.createLog({
      actorId: actor.userId,
      action:
        isPublished !== existing.isPublished
          ? isPublished
            ? 'ANNOUNCEMENT_PUBLISH'
            : 'ANNOUNCEMENT_UNPUBLISH'
          : 'ANNOUNCEMENT_UPDATE',
      resource: 'announcement',
      resourceId: id,
      description: `Updated announcement ${updated.title}`,
      metadata: {
        operatorRole: actor.role,
        before: this.snapshot(existing),
        after: this.snapshot(updated),
      },
    });
    return updated;
  }

  async remove(id: string, actor: { userId: string; role: string }) {
    const existing = await this.prisma.announcement.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Announcement not found');
    await this.prisma.announcement.delete({ where: { id } });
    await this.audit.createLog({
      actorId: actor.userId,
      action: 'ANNOUNCEMENT_DELETE',
      resource: 'announcement',
      resourceId: id,
      description: `Deleted announcement ${existing.title}`,
      metadata: {
        operatorRole: actor.role,
        before: this.snapshot(existing),
        after: null,
      },
    });
    return { ok: true };
  }

  private assertSchedule(startsAt?: string | null, endsAt?: string | null) {
    if (!startsAt || !endsAt) return;
    if (new Date(endsAt).getTime() < new Date(startsAt).getTime()) {
      throw new BadRequestException('endsAt must not be earlier than startsAt');
    }
  }

  private snapshot(row: {
    id: string;
    locale: string;
    title: string;
    body: string;
    type: AnnouncementType;
    isPublished: boolean;
    priority: number;
    startsAt: Date | null;
    endsAt: Date | null;
    sortOrder: number;
  }) {
    return { ...row };
  }

  private normalizeLocale(locale?: string) {
    const value = String(locale || 'en').trim().toLowerCase() || 'en';
    if (value !== 'en' && value !== 'hi') {
      throw new BadRequestException('Announcement locale must be en or hi');
    }
    return value;
  }

  private pickLocaleRows<T extends { id: string; locale: string; title: string }>(
    rows: T[],
    wanted: string,
  ) {
    // Prefer requested locale; include en-only items that have no preferred twin by title.
    const preferred = rows.filter((row) => row.locale === wanted);
    const preferredTitles = new Set(preferred.map((row) => row.title));
    const englishExtras = rows.filter(
      (row) => row.locale === 'en' && !preferredTitles.has(row.title),
    );
    return [...preferred, ...englishExtras];
  }
}
