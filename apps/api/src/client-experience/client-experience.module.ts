import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { ClientExperienceController } from './client-experience.controller';
import { ClientExperienceService } from './client-experience.service';

@Module({
  imports: [PrismaModule],
  controllers: [ClientExperienceController],
  providers: [ClientExperienceService],
  exports: [ClientExperienceService],
})
export class ClientExperienceModule {}
