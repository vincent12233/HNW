import type { DefaultContent } from './app-content.defaults.types';
import { ABOUT_DEFAULTS } from './app-content.defaults.about';
import { DEPOSIT_DEFAULTS } from './app-content.defaults.deposit';
import { HOME_DEFAULTS } from './app-content.defaults.home';
import { INSIGHTS_DEFAULTS } from './app-content.defaults.insights';
import { LEGAL_DEFAULTS } from './app-content.defaults.legal';
import { SUPPORT_DEFAULTS } from './app-content.defaults.support';
import { TRADING_DEFAULTS } from './app-content.defaults.trading';

export const APP_CONTENT_DEFAULTS: DefaultContent[] = [
  ...HOME_DEFAULTS,
  ...DEPOSIT_DEFAULTS,
  ...SUPPORT_DEFAULTS,
  ...TRADING_DEFAULTS,
  ...LEGAL_DEFAULTS,
  ...ABOUT_DEFAULTS,
  ...INSIGHTS_DEFAULTS,
];
