import { Module } from '@nestjs/common';
import { BusinessService } from './business.service';
import { BusinessController } from './business.controller';
import { IpoModule } from '../ipo/ipo.module';

@Module({
  imports: [IpoModule],
  providers: [BusinessService],
  controllers: [BusinessController],
})
export class BusinessModule {}
