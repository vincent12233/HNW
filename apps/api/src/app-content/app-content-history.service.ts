import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import {
  AppContentModule,
  AppContentPublicationStatus,
} from '../generated/prisma/enums';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import type { AppContentActor } from './app-content.service';

@Injectable()
export class AppContentHistoryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async listHistory(id: string) {
    const entry = await this.prisma.appContentEntry.findUnique({
      where: { id },
    });
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

  async restoreEntry(
    id: string,
    revisionId: string,
    expectedUpdatedAt: string,
    actor: AppContentActor,
  ) {
    if (typeof revisionId !== 'string' || !revisionId.trim())
      throw new BadRequestException('Revision ID is required');
    const expected = new Date(expectedUpdatedAt);
    if (!Number.isFinite(expected.getTime()))
      throw new BadRequestException('Valid expectedUpdatedAt is required');
    const revision = await this.prisma.auditLog.findFirst({
      where: { id: revisionId, resource: 'app_content', resourceId: id },
    });
    const data = revision?.metadata;
    const snapshot =
      data && typeof data === 'object' && !Array.isArray(data)
        ? (data as Record<string, unknown>).after
        : null;
    if (
      !snapshot ||
      typeof snapshot !== 'object' ||
      Array.isArray(snapshot) ||
      typeof (snapshot as Record<string, unknown>).body !== 'string'
    )
      throw new BadRequestException('Revision cannot be restored');
    const prior = snapshot as Record<string, unknown>;
    if (
      (typeof prior.title !== 'string' && prior.title !== null) ||
      typeof prior.isActive !== 'boolean' ||
      typeof prior.sortOrder !== 'number' ||
      !Number.isFinite(prior.sortOrder) ||
      (prior.body as string).length > 200_000
    )
      throw new BadRequestException('Revision snapshot is invalid');
    return this.prisma.$transaction(async (tx) => {
      const current = await tx.appContentEntry.findUnique({ where: { id } });
      if (!current) throw new NotFoundException('Content entry not found');
      if (current.updatedAt.getTime() !== expected.getTime())
        throw new ConflictException(
          'Content changed since history was opened; reload and try again',
        );
      if (
        current.module === AppContentModule.SUPPORT &&
        current.key === 'salesmartly_script_url'
      )
        throw new BadRequestException(
          'Restore the shared support URL through the editor',
        );
      const updated = await tx.appContentEntry.updateMany({
        where: { id, updatedAt: expected },
        data: {
          body: prior.body as string,
          title: prior.title as string | null,
          isActive: prior.isActive as boolean,
          sortOrder: prior.sortOrder as number,
          publicationStatus:
            (prior.publicationStatus as
              AppContentPublicationStatus | undefined) ??
            AppContentPublicationStatus.PUBLISHED,
          publishAt:
            typeof prior.publishAt === 'string'
              ? new Date(prior.publishAt)
              : null,
          expiresAt:
            typeof prior.expiresAt === 'string'
              ? new Date(prior.expiresAt)
              : null,
          version: { increment: 1 },
          ...(Object.hasOwn(prior, 'metadata')
            ? {
                metadata:
                  prior.metadata === null
                    ? Prisma.JsonNull
                    : (prior.metadata as Prisma.InputJsonValue),
              }
            : {}),
        },
      });
      if (updated.count !== 1)
        throw new ConflictException('Content changed; reload and try again');
      const restored = await tx.appContentEntry.findUniqueOrThrow({
        where: { id },
      });
      await this.audit.createLog(
        {
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
        },
        tx,
      );
      return restored;
    });
  }

  private snapshot(row: {
    title: string | null;
    body: string;
    metadata?: Prisma.JsonValue | null;
    isActive: boolean;
    sortOrder: number;
    publicationStatus: AppContentPublicationStatus;
    publishAt: Date | null;
    expiresAt: Date | null;
    version: number;
  }) {
    return {
      title: row.title,
      body: row.body,
      metadata: row.metadata ?? null,
      isActive: row.isActive,
      sortOrder: row.sortOrder,
      publicationStatus: row.publicationStatus,
      publishAt: row.publishAt?.toISOString() ?? null,
      expiresAt: row.expiresAt?.toISOString() ?? null,
      version: row.version,
    };
  }
}
