import { Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { IpoService } from './ipo.service';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('ipo')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CLIENT)
export class ClientIpoController {
  constructor(private readonly ipoService: IpoService) {}

  @Get('open')
  listOpenIpos() {
    return this.ipoService.listOpenIpos();
  }

  @Post(':ipoId/apply')
  apply(@Req() request: AuthenticatedRequest, @Param('ipoId') ipoId: string) {
    return this.ipoService.apply(request.user.userId, ipoId);
  }

  @Get('applications/me')
  listMyApplications(@Req() request: AuthenticatedRequest) {
    return this.ipoService.listMyApplications(request.user.userId);
  }

  @Get(':ipoId/application-limit')
  getApplicationLimit(
    @Req() request: AuthenticatedRequest,
    @Param('ipoId') ipoId: string,
  ) {
    return this.ipoService.getApplicationLimit(request.user.userId, ipoId);
  }

  @Get('debts/me')
  getMyDebts(@Req() request: AuthenticatedRequest) {
    return this.ipoService.listMyDebts(request.user.userId);
  }
}
