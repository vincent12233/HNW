import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';
import { SupportGateway } from './support.gateway';
import { AccountRecoveryService } from './account-recovery.service';
import { AccountRecoveryController, StaffRecoveryController } from './account-recovery.controller';
import { OperatorController } from './operator.controller';
import { OperatorService } from './operator.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [
    SupportController,
    AccountRecoveryController,
    StaffRecoveryController,
    OperatorController,
  ],
  providers: [
    SupportService,
    SupportGateway,
    AccountRecoveryService,
    OperatorService,
  ],
})
export class SupportModule {}
