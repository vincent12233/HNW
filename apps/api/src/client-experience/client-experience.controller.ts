import { Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ClientExperienceService } from './client-experience.service';
import { UserRole } from '../generated/prisma/enums';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class ClientExperienceController {
  constructor(private readonly service: ClientExperienceService) {}

  @Get('client/profile') @Roles(UserRole.CLIENT) profile(@Req() req: any) { return this.service.profile(req.user.userId); }
  @Patch('client/profile') @Roles(UserRole.CLIENT) updateProfile(@Req() req: any, @Body() body: any) { return this.service.updateProfile(req.user.userId, body); }
  @Post('client/security/password') @Roles(UserRole.CLIENT) password(@Req() req: any, @Body() body: any) { return this.service.changePassword(req.user.userId, body.currentPassword, body.newPassword); }
  @Get('client/security/devices') @Roles(UserRole.CLIENT) devices(@Req() req: any) { return this.service.devices(req.user.userId); }
  @Post('client/security/devices') @Roles(UserRole.CLIENT) registerDevice(@Req() req: any, @Body() body: any) { return this.service.registerDevice(req.user.userId, body); }
  @Delete('client/security/devices/:id') @Roles(UserRole.CLIENT) revokeDevice(@Req() req: any, @Param('id') id: string) { return this.service.revokeDevice(req.user.userId, id); }
  @Get('client/bank-accounts') @Roles(UserRole.CLIENT) banks(@Req() req: any) { return this.service.banks(req.user.userId); }
  @Post('client/bank-accounts') @Roles(UserRole.CLIENT) addBank(@Req() req: any, @Body() body: any) { return this.service.addBank(req.user.userId, body); }
  @Delete('client/bank-accounts/:id') @Roles(UserRole.CLIENT) deleteBank(@Req() req: any, @Param('id') id: string) { return this.service.deleteBank(req.user.userId, id); }
  @Get('client/preferences') @Roles(UserRole.CLIENT) preferences(@Req() req: any) { return this.service.preferences(req.user.userId); }
  @Patch('client/preferences') @Roles(UserRole.CLIENT) updatePreferences(@Req() req: any, @Body() body: any) { return this.service.updatePreferences(req.user.userId, body); }
  @Get('client/notifications') @Roles(UserRole.CLIENT) notifications(@Req() req: any) { return this.service.notifications(req.user.userId); }
  @Post('client/notifications/read-all') @Roles(UserRole.CLIENT) readAll(@Req() req: any) { return this.service.readAll(req.user.userId); }
  @Post('client/notifications/:id/read') @Roles(UserRole.CLIENT) read(@Req() req: any, @Param('id') id: string) { return this.service.read(req.user.userId, id); }
  @Get('client/portfolio/reconciliation') @Roles(UserRole.CLIENT) reconciliation(@Req() req: any) { return this.service.reconciliation(req.user.userId); }

  @Get('admin/bank-accounts') @Roles('ADMIN', 'FINANCE') adminBanks() { return this.service.adminBanks(); }
}
