import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { ClientExperienceController } from './client-experience.controller';
import { ClientExperienceService } from './client-experience.service';
import { WithdrawalPinService } from './withdrawal-pin.service';
import { TwoFactorModule } from '../auth/two-factor.module';

@Module({
  imports: [PrismaModule, TwoFactorModule],
  controllers: [ClientExperienceController],
  providers: [ClientExperienceService, WithdrawalPinService],
  exports: [ClientExperienceService, WithdrawalPinService],
})
export class ClientExperienceModule {}
