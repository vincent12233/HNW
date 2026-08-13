import { Body, Controller, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { OtcService } from './otc.service';

@Controller('otc')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OtcController {
  constructor(private readonly otc: OtcService) {}

  @Get('offers')
  offers() { return this.otc.listOffers(); }

  @Post('orders')
  submit(@Req() req: any, @Body() body: { offerId: string; priceTier: number; quantity: number; transactionKey: string }) {
    return this.otc.submit(req.user.userId, body.offerId, Number(body.priceTier), Number(body.quantity), body.transactionKey);
  }

  @Get('orders/me')
  mine(@Req() req: any) { return this.otc.myOrders(req.user.userId); }

  @Get('orders/pending')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS)
  pending(@Req() req: any) { return this.otc.pendingOrders(req.user.userId); }

  @Get('admin/offers')
  @Roles(UserRole.ADMIN)
  adminOffers() { return this.otc.listAdminOffers(); }

  @Post('admin/offers')
  @Roles(UserRole.ADMIN)
  createOffer(@Body() body: { instrumentId: string; tiers: Array<{ price: string; profit: string; transactionKey: string }>; validFrom: string; validUntil: string }) {
    return this.otc.saveOffer(body);
  }

  @Patch('admin/offers/:id')
  @Roles(UserRole.ADMIN)
  updateOffer(@Param('id') id: string, @Body() body: { price?: string; validFrom?: string; validUntil?: string; isActive?: boolean }) {
    return this.otc.updateOffer(id, body);
  }

  @Patch('orders/:id/approve')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS)
  approve(@Req() req: any, @Param('id') id: string) {
    return this.otc.approve(req.user.userId, id);
  }

  @Patch('orders/:id/reject')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS)
  reject(@Req() req: any, @Param('id') id: string, @Body() body: { note?: string }) {
    return this.otc.reject(req.user.userId, id, body.note);
  }
}
