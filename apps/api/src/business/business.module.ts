import { Module } from '@nestjs/common';
import { BusinessService } from './business.service';
import { BusinessController } from './business.controller';

@Module({
  providers: [BusinessService],
  controllers: [BusinessController],
})
export class BusinessModule {}
