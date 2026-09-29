import { Module } from '@nestjs/common';
import { AppContentController } from './app-content.controller';
import { AppContentService } from './app-content.service';
import { AppContentHistoryService } from './app-content-history.service';

@Module({
  controllers: [AppContentController],
  providers: [AppContentService, AppContentHistoryService],
  exports: [AppContentService],
})
export class AppContentModule {}
