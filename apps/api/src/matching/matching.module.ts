import { Module } from '@nestjs/common';

import { PrismaModule } from '../prisma/prisma.module';
import { MatchingScheduler } from './matching.scheduler';
import { MatchingService } from './matching.service';

@Module({
  imports: [PrismaModule],
  providers: [MatchingService, MatchingScheduler],
  exports: [MatchingService],
})
export class MatchingModule {}
