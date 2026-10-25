import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { AccountRecoveryService } from './account-recovery.service';
import {
  AccountRecoveryController,
  StaffRecoveryController,
} from './account-recovery.controller';
import { OperatorController } from './operator.controller';
import { OperatorService } from './operator.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [
    AccountRecoveryController,
    StaffRecoveryController,
    OperatorController,
  ],
  providers: [AccountRecoveryService, OperatorService],
})
export class SupportModule {}
