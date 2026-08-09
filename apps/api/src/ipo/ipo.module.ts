import { Module } from '@nestjs/common';
import { ClientIpoController } from './client-ipo.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { RolesGuard } from '../auth/roles.guard';

import { IpoService } from './ipo.service';
import { AdminIpoController } from './admin-ipo.controller';

@Module({
  imports: [PrismaModule, AuthModule],
  providers: [IpoService, RolesGuard],
  controllers: [AdminIpoController, ClientIpoController],
})
export class IpoModule {}
