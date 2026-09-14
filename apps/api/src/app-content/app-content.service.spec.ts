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
        ],
      },
      {
        module: AppContentModule.DEPOSIT,
        keys: ['instructions', 'chat_preset', 'api_reject_message'],
      },
      {
        module: AppContentModule.SUPPORT,
        keys: ['greeting', 'hours', 'chat_preset.help', 'chat_preset.deposit', 'salesmartly_script_url'],
      },
      {
        module: AppContentModule.TRADING,
        keys: [
          'institutional.empty_title',
          'institutional.empty_subtitle',
          'otc.empty_title',
          'otc.empty_subtitle',
          'ipo.confirm_template',
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
