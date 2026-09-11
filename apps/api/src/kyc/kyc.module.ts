import { Module } from '@nestjs/common';

import { PrismaModule } from '../prisma/prisma.module';
import { KycController } from './kyc.controller';
import { KycService } from './kyc.service';
import { AuthModule } from '../auth/auth.module';
import { KycAccessGuard } from './kyc-access.guard';
import { DedicatedOperatorScopeGuard } from '../business/dedicated-operator-scope.guard';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [KycController],
  providers: [KycService, KycAccessGuard, DedicatedOperatorScopeGuard],
  exports: [KycService],
})
export class KycModule {}
