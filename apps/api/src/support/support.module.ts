import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';
import { SupportGateway } from './support.gateway';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [
    SupportController,
  ],
  providers: [
    SupportService,
    SupportGateway,
  ],
})
export class SupportModule {}
