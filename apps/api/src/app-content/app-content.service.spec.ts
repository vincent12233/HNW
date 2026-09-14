import { AppContentService } from './app-content.service';

describe('AppContentService locale selection', () => {
  const service = Object.create(AppContentService.prototype) as AppContentService;

  it('prefers requested locale then falls back to English', () => {
    const pick = (service as any).pickLocale(
      [
        { module: 'HOME', key: 'banner.title', locale: 'en' },
        { module: 'HOME', key: 'banner.title', locale: 'hi' },
        { module: 'HOME', key: 'banner.subtitle', locale: 'en' },
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
});
