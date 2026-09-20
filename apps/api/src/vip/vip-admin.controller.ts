import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import type { AuthenticatedRequest } from '../auth/authenticated-request';
import { AdjustVipClientTierDto, UpdateVipTierDto } from './vip.dto';
import { VipConfigService } from './vip-config.service';
import { VipClientsService } from './vip-clients.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class VipAdminController {
  constructor(
    private readonly configs: VipConfigService,
    private readonly clients: VipClientsService,
  ) {}

  @Get('vip-tiers')
  listTiers() {
    return this.configs.list();
  }

  @Patch('vip-tiers/:tierCode')
  updateTier(
    @Req() req: AuthenticatedRequest,
    @Param('tierCode') tierCode: string,
    @Body() body: UpdateVipTierDto,
  ) {
    return this.configs.update(req.user.userId, tierCode, body);
  }

  @Get('vip-clients')
  listClients(@Req() req: AuthenticatedRequest) {
    return this.clients.list('ADMIN', req.user.userId);
  }

  @Get('vip-clients/:userId/history')
  clientHistory(
    @Req() req: AuthenticatedRequest,
    @Param('userId') userId: string,
  ) {
    return this.clients.history('ADMIN', req.user.userId, userId);
  }

  @Get('vip-history')
  history(@Req() req: AuthenticatedRequest) {
    return this.clients.listRecentHistory('ADMIN', req.user.userId);
  }

  @Patch('vip-clients/:userId/tier')
  adjust(
    @Req() req: AuthenticatedRequest,
    @Param('userId') userId: string,
    @Body() body: AdjustVipClientTierDto,
  ) {
    return this.clients.adjustOwnedClient(
      req.user.userId,
      userId,
      body.tier,
      body.reason,
      'ADMIN',
      true,
    );
  }
}
