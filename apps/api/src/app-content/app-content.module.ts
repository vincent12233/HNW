import { Module } from '@nestjs/common';
import { AppContentController } from './app-content.controller';
import { AppContentService } from './app-content.service';

@Module({
  controllers: [AppContentController],
  providers: [AppContentService],
  exports: [AppContentService],
})
export class AppContentModule {}
