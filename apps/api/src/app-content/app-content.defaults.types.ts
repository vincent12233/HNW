import { AppContentModule } from '../generated/prisma/enums';

export type DefaultContent = {
  module: AppContentModule;
  key: string;
  title?: string | null;
  body: string;
  locale?: string;
  sortOrder?: number;
  isActive?: boolean;
};
