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
import { AdjustVipClientTierDto } from './vip.dto';
import { VipClientsService } from './vip-clients.service';

@Controller('business/vip-clients')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.BUSINESS)
export class VipBusinessController {
  constructor(private readonly clients: VipClientsService) {}

  @Get()
  list(@Req() req: AuthenticatedRequest) {
    return this.clients.list('BUSINESS', req.user.userId);
  }

  @Get(':userId/history')
  history(
    @Req() req: AuthenticatedRequest,
    @Param('userId') userId: string,
  ) {
    return this.clients.history('BUSINESS', req.user.userId, userId);
  }

  @Patch(':userId/tier')
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
      'MANUAL',
      true,
    );
  }
}
