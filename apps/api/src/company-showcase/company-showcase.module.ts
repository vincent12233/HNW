import { Module } from '@nestjs/common';
import { CompanyShowcaseController } from './company-showcase.controller';
import { CompanyShowcaseService } from './company-showcase.service';

@Module({
  controllers: [CompanyShowcaseController],
  providers: [CompanyShowcaseService],
})
export class CompanyShowcaseModule {}
