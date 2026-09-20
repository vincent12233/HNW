import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { VipAdminController } from './vip-admin.controller';
import { VipBusinessController } from './vip-business.controller';
import { VipClientsService } from './vip-clients.service';
import { VipConfigService } from './vip-config.service';
import { VipTeamController } from './vip-team.controller';

@Module({
  imports: [PrismaModule],
  controllers: [
    VipAdminController,
    VipTeamController,
    VipBusinessController,
  ],
  providers: [VipConfigService, VipClientsService],
  exports: [VipConfigService, VipClientsService],
})
export class VipModule {}
