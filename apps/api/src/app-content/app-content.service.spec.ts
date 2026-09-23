import { AppContentModule } from '../generated/prisma/enums';
import { APP_CONTENT_DEFAULTS } from './app-content.defaults';
import {
  AppContentService,
  normalizeSaleSmartlyScriptUrl,
} from './app-content.service';
import {
  ADMIN_ONLY_SUPPORT_KEYS,
  isAdminOnlySupportKey,
} from './app-content.visibility';

describe('normalizeSaleSmartlyScriptUrl', () => {
  it('extracts src from a script tag', () => {
    expect(
      normalizeSaleSmartlyScriptUrl(
        '<script src="https://plugin-code.salesmartly.com/js/project_829333_860505_1789464929.js"></script>',
      ),
    ).toBe(
      'https://plugin-code.salesmartly.com/js/project_829333_860505_1789464929.js',
    );
  });

  it('keeps a bare URL', () => {
    expect(
      normalizeSaleSmartlyScriptUrl(
        'https://plugin-code.salesmartly.com/js/project_829333_860505_1789464929.js',
      ),
    ).toBe(
      'https://plugin-code.salesmartly.com/js/project_829333_860505_1789464929.js',
    );
  });
});

describe('admin-only support visibility', () => {
  it('marks desk tags and quick replies as admin-only', () => {
    expect(isAdminOnlySupportKey('tags')).toBe(true);
    expect(isAdminOnlySupportKey('quick_reply.deposit')).toBe(true);
    expect(isAdminOnlySupportKey('greeting')).toBe(false);
    expect(ADMIN_ONLY_SUPPORT_KEYS.size).toBe(5);
  });
});

describe('AppContentService locale selection', () => {
  const service = Object.create(
    AppContentService.prototype,
  ) as AppContentService;

  it('prefers requested locale then falls back to English', () => {
    const pick = (service as any).pickLocale(
      [
        {
          module: 'HOME',
          key: 'banner.title',
          locale: 'en',
          body: 'Live markets',
        },
        {
          module: 'HOME',
          key: 'banner.title',
          locale: 'hi',
          body: 'लाइव मार्केट',
        },
        {
          module: 'HOME',
          key: 'banner.subtitle',
          locale: 'en',
          body: 'Explore equities',
        },
      ],
      'hi',
    );
    expect(pick.localeUsed).toBe('hi');
    expect(pick.rows).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ key: 'banner.title', locale: 'hi' }),
        expect.objectContaining({ key: 'banner.subtitle', locale: 'en' }),
      ]),
    );
  });

  it('does not fall through to arbitrary locales such as zh', () => {
    const pick = (service as any).pickLocale(
      [
        {
          module: 'SUPPORT',
          key: 'greeting',
          locale: 'zh',
          body: '中文欢迎',
        },
        {
          module: 'SUPPORT',
          key: 'greeting',
          locale: 'en',
          body: 'Welcome',
        },
      ],
      'hi',
    );
    expect(pick.rows).toEqual([
      expect.objectContaining({ key: 'greeting', locale: 'en', body: 'Welcome' }),
    ]);
  });

  it('omits keys when neither requested nor en content exists', () => {
    const pick = (service as any).pickLocale(
      [
        {
          module: 'SUPPORT',
          key: 'tags',
          locale: 'zh',
          body: '入金,提现',
        },
      ],
      'hi',
    );
    expect(pick.rows).toEqual([]);
  });

  it('skips empty preferred-locale bodies and keeps filled English', () => {
    const pick = (service as any).pickLocale(
      [
        {
          module: 'SUPPORT',
          key: 'salesmartly_script_url',
          locale: 'en',
          body: 'https://example.com/script.js',
        },
        {
          module: 'SUPPORT',
          key: 'salesmartly_script_url',
          locale: 'hi',
          body: '',
        },
      ],
      'hi',
    );
    expect(pick.rows).toEqual([
      expect.objectContaining({
        key: 'salesmartly_script_url',
        locale: 'en',
        body: 'https://example.com/script.js',
      }),
    ]);
  });

  it('maps module rows into a key-keyed object and strips admin-only support keys', () => {
    const mapped = (service as any).moduleMap(
      [
        {
          module: AppContentModule.HOME,
          key: 'banner.title',
          title: null,
          body: 'Markets',
          locale: 'en',
          metadata: null,
          sortOrder: 1,
        },
        {
          module: AppContentModule.SUPPORT,
          key: 'tags',
          title: null,
          body: 'desk',
          locale: 'zh',
          metadata: null,
          sortOrder: 1,
        },
        {
          module: AppContentModule.SUPPORT,
          key: 'greeting',
          title: null,
          body: 'Hello',
          locale: 'en',
          metadata: null,
          sortOrder: 2,
        },
      ],
      AppContentModule.SUPPORT,
    );
    expect(mapped).toEqual({
      greeting: {
        title: null,
        body: 'Hello',
        locale: 'en',
        metadata: null,
        sortOrder: 2,
      },
    });
  });

  it('fills empty SaleSmartly script URL from SALESMARTLY_SCRIPT_URL', () => {
    const previous = process.env.SALESMARTLY_SCRIPT_URL;
    process.env.SALESMARTLY_SCRIPT_URL = 'https://cdn.example.com/ss.js';
    try {
      const support = (service as any).applySaleSmartlyScriptFallback({
        salesmartly_script_url: {
          title: null,
          body: '',
          locale: 'en',
          metadata: null,
          sortOrder: 40,
        },
      });
      expect(support.salesmartly_script_url.body).toBe(
        'https://cdn.example.com/ss.js',
      );
    } finally {
      if (previous === undefined) delete process.env.SALESMARTLY_SCRIPT_URL;
      else process.env.SALESMARTLY_SCRIPT_URL = previous;
    }
  });

  it('keeps CMS SaleSmartly script URL over env fallback', () => {
    const previous = process.env.SALESMARTLY_SCRIPT_URL;
    process.env.SALESMARTLY_SCRIPT_URL = 'https://cdn.example.com/env.js';
    try {
      const support = (service as any).applySaleSmartlyScriptFallback({
        salesmartly_script_url: {
          title: null,
          body: 'https://cdn.example.com/cms.js',
          locale: 'en',
          metadata: null,
          sortOrder: 40,
        },
      });
      expect(support.salesmartly_script_url.body).toBe(
        'https://cdn.example.com/cms.js',
      );
    } finally {
      if (previous === undefined) delete process.env.SALESMARTLY_SCRIPT_URL;
      else process.env.SALESMARTLY_SCRIPT_URL = previous;
    }
  });
});

function mockService(prisma: any, audit?: any) {
  return new AppContentService(prisma, {
    createLog: jest.fn().mockResolvedValue({ id: 'audit' }),
    ...audit,
  } as any);
}

describe('AppContentService SaleSmartly URL sync', () => {
  it('mirrors salesmartly_script_url to the other locale on upsert', async () => {
    const upsert = jest.fn().mockResolvedValue({
      id: 'row',
      title: null,
      body: 'https://cdn.example.com/widget.js',
      isActive: true,
      sortOrder: 0,
    });
    const findUnique = jest.fn().mockResolvedValue(null);
    const createLog = jest.fn().mockResolvedValue({ id: 'audit' });
    const service = mockService(
      { appContentEntry: { upsert, findUnique } },
      { createLog },
    );

    await service.upsertEntry(
      {
        module: 'SUPPORT',
        key: 'salesmartly_script_url',
        locale: 'en',
        body: '<script src="https://cdn.example.com/widget.js"></script>',
      },
      { userId: 'admin-1', role: 'ADMIN' },
    );

    expect(upsert).toHaveBeenCalledTimes(2);
    expect(upsert.mock.calls[0][0].where.module_key_locale.locale).toBe('en');
    expect(upsert.mock.calls[0][0].create.body).toBe(
      'https://cdn.example.com/widget.js',
    );
    expect(upsert.mock.calls[1][0].where.module_key_locale.locale).toBe('hi');
    expect(upsert.mock.calls[1][0].create.body).toBe(
      'https://cdn.example.com/widget.js',
    );
    expect(upsert.mock.calls[1][0].update.isActive).toBeUndefined();
    expect(createLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'APP_CONTENT_CREATE',
        resource: 'app_content',
        metadata: expect.objectContaining({
          operatorRole: 'ADMIN',
          key: 'salesmartly_script_url',
        }),
      }),
    );
  });

  it('preserves isActive and sortOrder when omitted on update', async () => {
    const existing = {
      id: 'row-1',
      module: AppContentModule.HOME,
      key: 'banner.title',
      locale: 'en',
      title: null,
      body: 'Old',
      isActive: false,
      sortOrder: 42,
    };
    const upsert = jest.fn().mockResolvedValue({
      ...existing,
      body: 'New',
    });
    const findUnique = jest.fn().mockResolvedValue(existing);
    const createLog = jest.fn().mockResolvedValue({ id: 'audit' });
    const service = mockService(
      { appContentEntry: { upsert, findUnique } },
      { createLog },
    );

    await service.upsertEntry(
      {
        module: 'HOME',
        key: 'banner.title',
        locale: 'en',
        body: 'New',
      },
      { userId: 'admin-1', role: 'ADMIN' },
    );

    expect(upsert.mock.calls[0][0].update.isActive).toBeUndefined();
    expect(upsert.mock.calls[0][0].update.sortOrder).toBeUndefined();
    expect(createLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'APP_CONTENT_UPDATE',
        metadata: expect.objectContaining({
          before: expect.objectContaining({ isActive: false, sortOrder: 42 }),
          after: expect.objectContaining({ body: 'New' }),
        }),
      }),
    );
  });

  it('audits delete with before snapshot', async () => {
    const existing = {
      id: 'del-1',
      module: AppContentModule.HOME,
      key: 'banner.title',
      locale: 'en',
      title: null,
      body: 'Gone',
      isActive: true,
      sortOrder: 1,
    };
    const findUnique = jest.fn().mockResolvedValue(existing);
    const del = jest.fn().mockResolvedValue(existing);
    const createLog = jest.fn().mockResolvedValue({ id: 'audit' });
    const service = mockService(
      { appContentEntry: { findUnique, delete: del } },
      { createLog },
    );

    await service.deleteEntry('del-1', { userId: 'admin-1', role: 'ADMIN' });
    expect(createLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'APP_CONTENT_DELETE',
        resourceId: 'del-1',
        metadata: expect.objectContaining({
          before: expect.objectContaining({ body: 'Gone' }),
          after: null,
        }),
      }),
    );
  });

  it('excludes admin-only support keys from the public bundle query', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const service = mockService({
      appContentEntry: {
        findMany,
        findUnique: jest.fn().mockResolvedValue({ id: 'x' }),
      },
    });
    (service as any).ensureDefaults = jest.fn().mockResolvedValue(undefined);

    await service.getPublicBundle('en');
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          isActive: true,
          NOT: expect.objectContaining({
            module: AppContentModule.SUPPORT,
          }),
        }),
      }),
    );
  });
});

describe('APP_CONTENT_DEFAULTS coverage', () => {
  it('keeps every operational content key available in English and Hindi', () => {
    const bilingualModules = new Set([
      AppContentModule.HOME,
      AppContentModule.DEPOSIT,
      AppContentModule.SUPPORT,
      AppContentModule.TRADING,
      AppContentModule.INSIGHTS,
    ]);
    const localesByKey = new Map<string, Set<string>>();
    for (const entry of APP_CONTENT_DEFAULTS) {
      if (!bilingualModules.has(entry.module) || entry.locale === 'zh') continue;
      const key = `${entry.module}:${entry.key}`;
      if (!localesByKey.has(key)) localesByKey.set(key, new Set());
      localesByKey.get(key)!.add(entry.locale || 'en');
    }

    for (const [key, locales] of localesByKey) {
      expect({ key, locales: [...locales].sort() }).toEqual({
        key,
        locales: ['en', 'hi'],
      });
    }
  });

  it('includes HOME/DEPOSIT/SUPPORT/TRADING defaults for en and hi', () => {
    const byModuleLocale = new Map<string, Set<string>>();
    for (const entry of APP_CONTENT_DEFAULTS) {
      const locale = entry.locale || 'en';
      const key = `${entry.module}:${locale}`;
      if (!byModuleLocale.has(key)) byModuleLocale.set(key, new Set());
      byModuleLocale.get(key)!.add(entry.key);
    }

    const required: Array<{ module: AppContentModule; keys: string[] }> = [
      {
        module: AppContentModule.HOME,
        keys: [
          'banner.title',
          'banner.subtitle',
          'markets.banner.title',
          'markets.banner.subtitle',
          'company.section_title',
          'company.video_cta',
          'company.website_cta',
          'funds.cta_label',
          'funds.cta_subtitle',
          'funds.withdraw_cta_label',
          'funds.withdraw_cta_subtitle',
          'funds.trade_cta_label',
          'funds.trade_cta_subtitle',
          'funds.total_asset_label',
          'funds.available_label',
          'indices.section_title',
          'view_all_cta',
          'news.section_title',
          'news.empty',
          'profile.page_title',
          'profile.section.overview',
          'profile.section.account',
          'profile.section.funds',
          'profile.section.security',
          'profile.section.preferences',
          'profile.section.support',
          'profile.section.legal',
          'profile.metric.available',
          'profile.metric.portfolio',
          'profile.metric.returns',
          'profile.tile.help.title',
          'profile.tile.help.subtitle',
          'profile.tile.insights.title',
          'profile.tile.insights.subtitle',
          'profile.tile.about.title',
          'profile.tile.about.subtitle',
          'profile.tile.risk.title',
          'profile.tile.terms.title',
          'profile.tile.privacy.title',
          'profile.logout_label',
          'profile.logout_subtitle',
          'withdraw.dialog_title',
          'withdraw.available_label',
          'withdraw.frozen_template',
          'withdraw.amount_label',
          'withdraw.min_hint',
          'withdraw.pin_label',
          'withdraw.bank_section_title',
          'withdraw.bank_picker_label',
          'withdraw.holder_label',
          'withdraw.account_label',
          'withdraw.status_label',
          'withdraw.notice',
          'withdraw.records_title',
          'withdraw.cancel',
          'withdraw.submit',
          'withdraw.bank_incomplete',
          'withdraw.submitting',
          'withdraw.min_error',
          'withdraw.max_error_template',
          'withdraw.bank_error',
          'withdraw.pin_error',
        ],
      },
      {
        module: AppContentModule.DEPOSIT,
        keys: [
          'page_title',
          'hero_title',
          'instructions',
          'cta_label',
          'chat_preset',
          'api_reject_message',
          'history_section_title',
          'history_empty',
          'terms_section_title',
          'terms',
        ],
      },
      {
        module: AppContentModule.SUPPORT,
        keys: [
          'fab_label',
          'header_title',
          'greeting',
          'hours',
          'quick_topics_label',
          'topic.deposit',
          'topic.trading',
          'topic.account',
          'composer_hint',
          'chat_preset.help',
          'chat_preset.deposit',
          'salesmartly_script_url',
        ],
      },
      {
        module: AppContentModule.TRADING,
        keys: [
          'tab.trades',
          'tab.institutional',
          'tab.holdings',
          'tab.pending',
          'tab.order_book',
          'tab.otc',
          'tab.ipo',
          'tab.history',
          'tab.funds_ledger',
          'tab.all',
          'tab.ins_stock',
          'shortcut.overview',
          'shortcut.orders',
          'institutional.empty_title',
          'institutional.empty_subtitle',
          'otc.empty_title',
          'otc.empty_subtitle',
          'ipo.confirm_template',
          'ipo.empty_open_title',
          'ipo.empty_open_subtitle',
          'ipo.empty_title',
          'ipo.empty_subtitle',
          'portfolio.page_title',
          'portfolio.page_subtitle',
          'portfolio.value_label',
          'portfolio.summary_heading',
          'portfolio.allocation_heading',
          'portfolio.empty_title',
          'portfolio.empty_subtitle',
          'portfolio.explore_cta',
          'holdings.empty_title',
          'holdings.empty_subtitle',
          'guide.institutional',
          'guide.otc',
          'guide.ipo',
        ],
      },
    ];

    for (const locale of ['en', 'hi'] as const) {
      for (const group of required) {
        const keys = byModuleLocale.get(`${group.module}:${locale}`);
        expect(keys).toBeDefined();
        for (const key of group.keys) {
          expect(keys!.has(key)).toBe(true);
        }
      }
    }

    const holdingsEn = APP_CONTENT_DEFAULTS.find(
      (row) =>
        row.module === AppContentModule.TRADING &&
        row.key === 'tab.holdings' &&
        row.locale === 'en',
    );
    expect(holdingsEn?.body).toBe('Positions');
    const allEn = APP_CONTENT_DEFAULTS.find(
      (row) =>
        row.module === AppContentModule.TRADING &&
        row.key === 'tab.all' &&
        row.locale === 'en',
    );
    expect(allEn?.body).toBe('Overview');
  });

  it('seeds missing defaults without overwriting existing rows', async () => {
    const existing = new Set(['HOME:banner.title:en']);
    const created: Array<{ module: string; key: string; locale: string }> = [];
    const prisma = {
      appContentEntry: {
        findUnique: jest.fn(async ({ where }: any) => {
          const id = `${where.module_key_locale.module}:${where.module_key_locale.key}:${where.module_key_locale.locale}`;
          return existing.has(id) ? { id } : null;
        }),
        create: jest.fn(async ({ data }: any) => {
          created.push({
            module: data.module,
            key: data.key,
            locale: data.locale,
          });
          return data;
        }),
        update: jest.fn(),
      },
    };
    const service = mockService(prisma);
    await (service as any).seedMissingDefaults();
    expect(created.length).toBeGreaterThan(0);
    expect(
      created.some(
        (row) =>
          row.module === 'HOME' &&
          row.key === 'banner.title' &&
          row.locale === 'en',
      ),
    ).toBe(false);
  });
});
