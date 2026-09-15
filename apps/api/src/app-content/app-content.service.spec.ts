import { AppContentModule } from '../generated/prisma/enums';
import { APP_CONTENT_DEFAULTS } from './app-content.defaults';
import { AppContentService } from './app-content.service';

describe('AppContentService locale selection', () => {
  const service = Object.create(AppContentService.prototype) as AppContentService;

  it('prefers requested locale then falls back to English', () => {
    const pick = (service as any).pickLocale(
      [
        { module: 'HOME', key: 'banner.title', locale: 'en', body: 'Live markets' },
        { module: 'HOME', key: 'banner.title', locale: 'hi', body: 'लाइव मार्केट' },
        { module: 'HOME', key: 'banner.subtitle', locale: 'en', body: 'Explore equities' },
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

  it('maps module rows into a key-keyed object', () => {
    const mapped = (service as any).moduleMap(
      [
        {
          module: AppContentModule.HOME,
          key: 'banner.title',
          title: null,
          body: 'Markets',
          locale: 'en',
        },
        {
          module: AppContentModule.DEPOSIT,
          key: 'instructions',
          title: null,
          body: 'Pay via support',
          locale: 'en',
        },
      ],
      AppContentModule.HOME,
    );
    expect(mapped).toEqual({
      'banner.title': { title: null, body: 'Markets', locale: 'en' },
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

describe('AppContentService SaleSmartly URL sync', () => {
  it('mirrors salesmartly_script_url to the other locale on upsert', async () => {
    const upsert = jest.fn().mockResolvedValue({ id: 'row' });
    const service = new AppContentService({
      appContentEntry: { upsert },
    } as any);

    await service.upsertEntry({
      module: 'SUPPORT',
      key: 'salesmartly_script_url',
      locale: 'en',
      body: 'https://cdn.example.com/widget.js',
    });

    expect(upsert).toHaveBeenCalledTimes(2);
    expect(upsert.mock.calls[0][0].where.module_key_locale.locale).toBe('en');
    expect(upsert.mock.calls[1][0].where.module_key_locale.locale).toBe('hi');
    expect(upsert.mock.calls[1][0].create.body).toBe(
      'https://cdn.example.com/widget.js',
    );
  });
});

describe('APP_CONTENT_DEFAULTS coverage', () => {
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
          'funds.total_asset_label',
          'funds.available_label',
          'indices.section_title',
          'view_all_cta',
          'news.section_title',
          'news.empty',
          'profile.page_title',
          'profile.section.overview',
          'profile.section.security',
          'profile.section.preferences',
          'profile.section.support',
          'profile.metric.available',
          'profile.metric.portfolio',
          'profile.metric.returns',
          'profile.tile.help.title',
          'profile.tile.help.subtitle',
          'profile.tile.insights.title',
          'profile.tile.insights.subtitle',
          'profile.tile.about.title',
          'profile.tile.about.subtitle',
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
      },
    };

    const service = new AppContentService(prisma as any);
    await (service as any).seedMissingDefaults();

    expect(
      created.some(
        (row) =>
          row.module === AppContentModule.HOME &&
          row.key === 'banner.title' &&
          row.locale === 'en',
      ),
    ).toBe(false);
    expect(
      created.some(
        (row) =>
          row.module === AppContentModule.HOME &&
          row.key === 'banner.title' &&
          row.locale === 'hi',
      ),
    ).toBe(true);
    expect(created.length).toBeGreaterThan(10);
  });
});
