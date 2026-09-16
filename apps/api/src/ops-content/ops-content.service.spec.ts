import { AnnouncementType, AppClientPlatform } from '../generated/prisma/enums';
import { AnnouncementsService } from './announcements.service';
import { AppClientSettingsService } from './app-client-settings.service';
import { InsightArticlesService } from './insight-articles.service';
import { LEGACY_INSIGHT_IMPORTS } from './insight-legacy-import';

describe('LEGACY_INSIGHT_IMPORTS', () => {
  it('covers eight articles in en and hi with unique slug+locale', () => {
    expect(LEGACY_INSIGHT_IMPORTS).toHaveLength(16);
    const keys = new Set(
      LEGACY_INSIGHT_IMPORTS.map((row) => `${row.slug}:${row.locale}`),
    );
    expect(keys.size).toBe(16);
    expect(
      new Set(LEGACY_INSIGHT_IMPORTS.map((row) => row.legacyKey)).size,
    ).toBe(8);
  });
});

describe('InsightArticlesService', () => {
  it('imports legacy rows idempotently and lists published locale picks', async () => {
    const upsert = jest.fn().mockResolvedValue({});
    const findMany = jest.fn().mockResolvedValue([
      {
        id: '1',
        slug: 'account-and-kyc',
        locale: 'hi',
        title: 'HI',
        summary: null,
        body: 'b',
        imageUrl: null,
        sortOrder: 10,
        publishedAt: new Date(),
      },
      {
        id: '2',
        slug: 'account-and-kyc',
        locale: 'en',
        title: 'EN',
        summary: null,
        body: 'b',
        imageUrl: null,
        sortOrder: 10,
        publishedAt: new Date(),
      },
    ]);
    const service = new InsightArticlesService(
      { insightArticle: { upsert, findMany } } as any,
      { createLog: jest.fn() } as any,
    );
    const rows = await service.listPublic('hi');
    expect(upsert).toHaveBeenCalled();
    expect(rows).toHaveLength(1);
    expect(rows[0].locale).toBe('hi');
  });

  it('creates with audit and publish timestamp', async () => {
    const create = jest.fn().mockResolvedValue({
      id: 'a1',
      slug: 'demo',
      locale: 'en',
      title: 'Demo',
      summary: null,
      body: 'Body',
      imageUrl: null,
      isPublished: true,
      sortOrder: 1,
      publishedAt: new Date('2026-01-01'),
    });
    const createLog = jest.fn().mockResolvedValue({});
    const service = new InsightArticlesService(
      { insightArticle: { create } } as any,
      { createLog } as any,
    );
    await service.create(
      {
        slug: 'demo',
        locale: 'en',
        title: 'Demo',
        body: 'Body',
        isPublished: true,
        sortOrder: 1,
      },
      { userId: 'admin', role: 'ADMIN' },
    );
    expect(createLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'INSIGHT_ARTICLE_CREATE',
        metadata: expect.objectContaining({ operatorRole: 'ADMIN' }),
      }),
    );
  });

  it('hides unpublished from public slug lookup', async () => {
    const service = new InsightArticlesService(
      {
        insightArticle: {
          upsert: jest.fn(),
          findMany: jest.fn().mockResolvedValue([]),
        },
      } as any,
      { createLog: jest.fn() } as any,
    );
    await expect(service.getPublicBySlug('missing', 'en')).rejects.toThrow(
      'Insight article not found',
    );
  });
});

describe('AnnouncementsService', () => {
  it('rejects endsAt before startsAt', async () => {
    const service = new AnnouncementsService(
      { announcement: { create: jest.fn() } } as any,
      { createLog: jest.fn() } as any,
    );
    await expect(
      service.create(
        {
          locale: 'en',
          title: 'Maint',
          body: 'Down',
          startsAt: '2026-09-20T10:00:00.000Z',
          endsAt: '2026-09-19T10:00:00.000Z',
        },
        { userId: 'admin', role: 'ADMIN' },
      ),
    ).rejects.toThrow('endsAt must not be earlier than startsAt');
  });

  it('creates and audits announcements', async () => {
    const created = {
      id: 'n1',
      locale: 'en',
      title: 'Hello',
      body: 'World',
      type: AnnouncementType.GENERAL,
      isPublished: true,
      priority: 1,
      startsAt: null,
      endsAt: null,
      sortOrder: 0,
    };
    const create = jest.fn().mockResolvedValue(created);
    const createLog = jest.fn().mockResolvedValue({});
    const service = new AnnouncementsService(
      { announcement: { create } } as any,
      { createLog } as any,
    );
    await service.create(
      { locale: 'en', title: 'Hello', body: 'World', isPublished: true },
      { userId: 'admin', role: 'ADMIN' },
    );
    expect(createLog).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'ANNOUNCEMENT_CREATE' }),
    );
  });

  it('filters public list by schedule window', async () => {
    const findMany = jest.fn().mockResolvedValue([
      {
        id: '1',
        locale: 'en',
        title: 'Live',
        body: 'x',
        type: AnnouncementType.GENERAL,
        priority: 0,
        startsAt: null,
        endsAt: null,
        sortOrder: 0,
      },
    ]);
    const service = new AnnouncementsService(
      { announcement: { findMany } } as any,
      { createLog: jest.fn() } as any,
    );
    const rows = await service.listPublic('en');
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ isPublished: true }),
      }),
    );
    expect(rows[0].title).toBe('Live');
  });
});

describe('AppClientSettingsService', () => {
  it('ensures platform uniqueness defaults and returns public shape', async () => {
    const upsert = jest.fn().mockResolvedValue({});
    const findUnique = jest.fn().mockResolvedValue({
      id: 's1',
      platform: AppClientPlatform.ANDROID,
      minVersion: '1.0.0',
      latestVersion: '1.2.0',
      forceUpdate: false,
      maintenanceMode: false,
      maintenanceMessage: null,
      supportUrl: null,
      updatedAt: new Date(),
    });
    const service = new AppClientSettingsService(
      { appClientSetting: { upsert, findUnique } } as any,
      { createLog: jest.fn() } as any,
    );
    const row = await service.getPublic('ANDROID');
    expect(upsert).toHaveBeenCalledTimes(3);
    expect(row.forceUpdate).toBe(false);
    expect(row.maintenanceMode).toBe(false);
  });

  it('audits settings updates', async () => {
    const before = {
      id: 's1',
      platform: AppClientPlatform.WEB,
      minVersion: '0.0.0',
      latestVersion: '0.0.0',
      forceUpdate: false,
      maintenanceMode: false,
      maintenanceMessage: null,
      supportUrl: null,
    };
    const findUnique = jest.fn().mockResolvedValue(before);
    const update = jest.fn().mockResolvedValue({
      ...before,
      maintenanceMode: true,
      maintenanceMessage: 'Upgrading',
    });
    const createLog = jest.fn().mockResolvedValue({});
    const service = new AppClientSettingsService(
      {
        appClientSetting: {
          upsert: jest.fn(),
          findUnique,
          update,
        },
      } as any,
      { createLog } as any,
    );
    await service.upsert(
      {
        platform: AppClientPlatform.WEB,
        minVersion: '0.0.0',
        latestVersion: '1.0.0',
        maintenanceMode: true,
        maintenanceMessage: 'Upgrading',
      },
      { userId: 'admin', role: 'ADMIN' },
    );
    expect(createLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'APP_CLIENT_SETTING_UPDATE',
        metadata: expect.objectContaining({
          before: expect.objectContaining({ maintenanceMode: false }),
          after: expect.objectContaining({ maintenanceMode: true }),
        }),
      }),
    );
  });

  it('safeDefaults never force-lock clients', () => {
    const service = new AppClientSettingsService({} as any, {} as any);
    const defaults = service.safeDefaults(AppClientPlatform.IOS);
    expect(defaults.forceUpdate).toBe(false);
    expect(defaults.maintenanceMode).toBe(false);
  });
});
