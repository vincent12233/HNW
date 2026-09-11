import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ClientExperienceService } from './client-experience.service';
import { UserRole } from '../generated/prisma/enums';
import { WithdrawalPinService } from './withdrawal-pin.service';
import { TwoFactorService } from '../auth/two-factor.service';

@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class ClientExperienceController {
  constructor(private readonly service: ClientExperienceService, private readonly pins: WithdrawalPinService, private readonly twoFactor: TwoFactorService) {}

  @Get('client/security/two-factor') @Roles(UserRole.CLIENT) twoFactorStatus(@Req() req: any) { return this.twoFactor.status(req.user.userId); }
  @Post('client/security/two-factor/setup') @Roles(UserRole.CLIENT) twoFactorSetup(@Req() req: any, @Body() body: any) { return this.twoFactor.setup(req.user.userId, body.currentPassword); }
  @Post('client/security/two-factor/confirm') @Roles(UserRole.CLIENT) twoFactorConfirm(@Req() req: any, @Body() body: any) { return this.twoFactor.confirm(req.user.userId, body.code); }
  @Post('client/security/two-factor/disable') @Roles(UserRole.CLIENT) twoFactorDisable(@Req() req: any, @Body() body: any) { return this.twoFactor.disable(req.user.userId, body.currentPassword, body.code); }

  @Get('client/security/withdrawal-pin') @Roles(UserRole.CLIENT) pinStatus(@Req() req: any) { return this.pins.status(req.user.userId); }
  @Post('client/security/withdrawal-pin') @Roles(UserRole.CLIENT) changePin(@Req() req: any, @Body() body: any) { return this.pins.change(req.user.userId, body); }

  @Get('client/profile') @Roles(UserRole.CLIENT) profile(@Req() req: any) { return this.service.profile(req.user.userId); }
  @Patch('client/profile/avatar') @Roles(UserRole.CLIENT) avatar(@Req() req: any, @Body() body: any) { return this.service.updateAvatar(req.user.userId, body.base64); }
  @Patch('admin/clients/:id/tier') @Roles(UserRole.ADMIN) tier(@Req() req: any, @Param('id') id: string, @Body() body: any) { return this.service.updateTier(req.user.userId, id, body.tier); }
  @Get('client/assets/history') @Roles(UserRole.CLIENT) history(@Req() req: any, @Query('period') period = '1D') { return this.service.assetHistory(req.user.userId, period); }
  @Get('client/portfolio/products') @Roles(UserRole.CLIENT) products(@Req() req: any, @Query('period') period = '1M') { return this.service.productPortfolio(req.user.userId, period); }
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
