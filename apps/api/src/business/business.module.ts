import { Module } from '@nestjs/common';
import { BusinessService } from './business.service';
import { BusinessController } from './business.controller';
import { IpoModule } from '../ipo/ipo.module';
import { KycModule } from '../kyc/kyc.module';
import { TeamController } from './team.controller';
import { TeamService } from './team.service';
import { DedicatedOperatorScopeGuard } from './dedicated-operator-scope.guard';

@Module({
  imports: [IpoModule, KycModule],
  providers: [BusinessService, TeamService, DedicatedOperatorScopeGuard],
  controllers: [BusinessController, TeamController],
})
export class BusinessModule {}
