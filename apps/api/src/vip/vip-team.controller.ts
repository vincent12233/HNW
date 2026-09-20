import {
  Controller,
  Get,
  Param,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import type { AuthenticatedRequest } from '../auth/authenticated-request';
import { VipClientsService } from './vip-clients.service';

@Controller('team/vip-clients')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.MANAGER)
export class VipTeamController {
  constructor(private readonly clients: VipClientsService) {}

  @Get()
  list(@Req() req: AuthenticatedRequest) {
    return this.clients.list('MANAGER', req.user.userId);
  }

  @Get(':userId/history')
  history(
    @Req() req: AuthenticatedRequest,
    @Param('userId') userId: string,
  ) {
    return this.clients.history('MANAGER', req.user.userId, userId);
  }
}
