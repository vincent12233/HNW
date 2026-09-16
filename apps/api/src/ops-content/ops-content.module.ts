import { Module } from '@nestjs/common';
import { AnnouncementsService } from './announcements.service';
import { AppClientSettingsService } from './app-client-settings.service';
import { InsightArticlesService } from './insight-articles.service';
import { OpsContentController } from './ops-content.controller';

@Module({
  controllers: [OpsContentController],
  providers: [
    InsightArticlesService,
    AnnouncementsService,
    AppClientSettingsService,
  ],
  exports: [
    InsightArticlesService,
    AnnouncementsService,
    AppClientSettingsService,
  ],
})
export class OpsContentModule {}
