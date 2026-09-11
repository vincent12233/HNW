import { Module } from '@nestjs/common';
import { WithdrawalController } from './withdrawal.controller';
import { WithdrawalService } from './withdrawal.service';
import { AuditModule } from '../audit/audit.module';
import { ClientExperienceModule } from '../client-experience/client-experience.module';

@Module({
  imports: [AuditModule, ClientExperienceModule],
  controllers: [WithdrawalController],
  providers: [WithdrawalService],
})
export class WithdrawalModule {}
