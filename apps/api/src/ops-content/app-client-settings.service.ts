import { Injectable, NotFoundException } from '@nestjs/common';
import { AppClientPlatform } from '../generated/prisma/enums';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { UpsertAppClientSettingDto } from './dto/ops-content.dto';

const PLATFORMS = Object.values(AppClientPlatform);

@Injectable()
export class AppClientSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async ensureDefaults() {
    for (const platform of PLATFORMS) {
      await this.prisma.appClientSetting.upsert({
        where: { platform },
        create: {
          platform,
          minVersion: '0.0.0',
          latestVersion: '0.0.0',
          forceUpdate: false,
          maintenanceMode: false,
        },
        update: {},
      });
    }
  }

  async getPublic(platform: string) {
    await this.ensureDefaults();
    const normalized = this.parsePlatform(platform);
    const row = await this.prisma.appClientSetting.findUnique({
      where: { platform: normalized },
    });
    if (!row) {
      return this.safeDefaults(normalized);
    }
    return {
      platform: row.platform,
      minVersion: row.minVersion,
      latestVersion: row.latestVersion,
      forceUpdate: row.forceUpdate,
      maintenanceMode: row.maintenanceMode,
      maintenanceMessage: row.maintenanceMessage,
      supportUrl: row.supportUrl,
      updateUrl: row.updateUrl,
      updatedAt: row.updatedAt,
    };
  }

  async listAdmin() {
    await this.ensureDefaults();
    return this.prisma.appClientSetting.findMany({
      orderBy: { platform: 'asc' },
    });
  }

  async upsert(
    dto: UpsertAppClientSettingDto & { platform: AppClientPlatform },
    actor: { userId: string; role: string },
  ) {
    await this.ensureDefaults();
    const platform = dto.platform;
    const before = await this.prisma.appClientSetting.findUnique({
      where: { platform },
    });
    if (!before) throw new NotFoundException('App client setting not found');
    const updated = await this.prisma.appClientSetting.update({
      where: { platform },
      data: {
        minVersion: dto.minVersion,
        latestVersion: dto.latestVersion,
        forceUpdate: dto.forceUpdate ?? before.forceUpdate,
        maintenanceMode: dto.maintenanceMode ?? before.maintenanceMode,
        maintenanceMessage:
          dto.maintenanceMessage === undefined
            ? undefined
            : dto.maintenanceMessage?.trim() || null,
        supportUrl:
          dto.supportUrl === undefined
            ? undefined
            : dto.supportUrl?.trim() || null,
        updateUrl:
          dto.updateUrl === undefined
            ? undefined
            : dto.updateUrl?.trim() || null,
        updatedById: actor.userId,
      },
    });
    await this.audit.createLog({
      actorId: actor.userId,
      action: 'APP_CLIENT_SETTING_UPDATE',
      resource: 'app_client_setting',
      resourceId: updated.id,
      description: `Updated app settings for ${platform}`,
      metadata: {
        operatorRole: actor.role,
        platform,
        before: this.snapshot(before),
        after: this.snapshot(updated),
      },
    });
    return updated;
  }

  /** Safe offline defaults when API unavailable (client-side mirror). */
  safeDefaults(platform: AppClientPlatform) {
    return {
      platform,
      minVersion: '0.0.0',
      latestVersion: '0.0.0',
      forceUpdate: false,
      maintenanceMode: false,
      maintenanceMessage: null as string | null,
      supportUrl: null as string | null,
      updateUrl: null as string | null,
      updatedAt: null as Date | null,
    };
  }

  private parsePlatform(value: string): AppClientPlatform {
    const normalized = String(value || '')
      .trim()
      .toUpperCase();
    if (!PLATFORMS.includes(normalized as AppClientPlatform)) {
      return AppClientPlatform.WEB;
    }
    return normalized as AppClientPlatform;
  }

  private snapshot(row: {
    id: string;
    platform: AppClientPlatform;
    minVersion: string;
    latestVersion: string;
    forceUpdate: boolean;
    maintenanceMode: boolean;
    maintenanceMessage: string | null;
    supportUrl: string | null;
    updateUrl: string | null;
  }) {
    return { ...row };
  }
}
