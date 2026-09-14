import { Module } from '@nestjs/common';
import { DepositService } from './deposit.service';
import { DepositController } from './deposit.controller';
import { AuditModule } from '../audit/audit.module';
import { AppContentModule } from '../app-content/app-content.module';

@Module({
  imports: [AuditModule, AppContentModule],
  providers: [DepositService],
  controllers: [DepositController],
})
export class DepositModule {}
