import { Module } from '@nestjs/common';
import { BusinessService } from './business.service';
import { BusinessController } from './business.controller';
import { IpoModule } from '../ipo/ipo.module';
import { KycModule } from '../kyc/kyc.module';
import { TeamController } from './team.controller';
import { TeamService } from './team.service';
import { DedicatedOperatorScopeGuard } from './dedicated-operator-scope.guard';
import { BusinessAssignmentService } from './business-assignment.service';
import { BusinessAssignmentAdminController } from './business-assignment.controller';

@Module({
  imports: [IpoModule, KycModule],
  providers: [
    BusinessService,
    TeamService,
    BusinessAssignmentService,
    DedicatedOperatorScopeGuard,
  ],
  controllers: [
    BusinessController,
    TeamController,
    BusinessAssignmentAdminController,
  ],
})
export class BusinessModule {}
