import { Module } from '@nestjs/common';
import { BusinessService } from './business.service';
import { BusinessController } from './business.controller';
import { IpoModule } from '../ipo/ipo.module';
import { KycModule } from '../kyc/kyc.module';
import { TeamController } from './team.controller';
import { TeamService } from './team.service';

@Module({
  imports: [IpoModule, KycModule],
  providers: [BusinessService, TeamService],
  controllers: [BusinessController, TeamController],
})
export class BusinessModule {}
