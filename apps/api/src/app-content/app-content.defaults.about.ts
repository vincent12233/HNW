import { AppContentModule } from '../generated/prisma/enums';
import type { DefaultContent } from './app-content.defaults.types';

export const ABOUT_DEFAULTS: DefaultContent[] = [
  {
    module: AppContentModule.ABOUT,
    key: 'company_name',
    body: 'India Trading App',
    locale: 'en',
    sortOrder: 10,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'legal_name',
    body: '',
    locale: 'en',
    sortOrder: 20,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'registered_address',
    body: '',
    locale: 'en',
    sortOrder: 30,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'grievance_contact',
    body: '',
    locale: 'en',
    sortOrder: 40,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'app_version',
    // Marketing / display label only — not the client PackageInfo / pubspec build.
    body: 'Version 1.0.0',
    locale: 'en',
    sortOrder: 50,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'summary',
    body: 'Professional trading access for equities, institutional offers, OTC and IPOs. Complete legal entity, registered address and grievance contacts before public release.',
    locale: 'en',
    sortOrder: 60,
  },
];
