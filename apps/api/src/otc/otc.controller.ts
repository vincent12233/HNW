import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { CreateOtcOfferDto } from './dto/create-otc-offer.dto';
import { SubmitOtcOrderDto } from './dto/submit-otc-order.dto';
import { UpdateOtcOfferDto } from './dto/update-otc-offer.dto';
import { OtcService } from './otc.service';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('otc')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OtcController {
  constructor(private readonly otc: OtcService) {}

  @Get('offers')
  @Roles(UserRole.CLIENT)
  offers() {
    return this.otc.listOffers();
  }

  @Post('orders')
  @Roles(UserRole.CLIENT)
  submit(@Req() req: AuthenticatedRequest, @Body() body: SubmitOtcOrderDto) {
    return this.otc.submit(
      req.user.userId,
      body.offerId,
      body.quantity,
      body.transactionKey,
    );
  }

  @Get('orders/me')
  @Roles(UserRole.CLIENT)
  mine(@Req() req: AuthenticatedRequest) {
    return this.otc.myOrders(req.user.userId);
  }

  @Get('orders/pending')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS, UserRole.SUPPORT)
  pending(@Req() req: AuthenticatedRequest) {
    return this.otc.pendingOrders(req.user.userId);
  }

  @Get('admin/offers')
  @Roles(UserRole.ADMIN)
  adminOffers() {
    return this.otc.listAdminOffers();
  }

  @Post('admin/offers')
  @Roles(UserRole.ADMIN)
  createOffer(@Body() body: CreateOtcOfferDto) {
    return this.otc.saveOffer(body);
  }

  @Patch('admin/offers/:id')
  @Roles(UserRole.ADMIN)
  updateOffer(@Param('id') id: string, @Body() body: UpdateOtcOfferDto) {
    return this.otc.updateOffer(id, body);
  }

  @Patch('orders/:id/approve')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS, UserRole.SUPPORT)
  approve(@Req() req: AuthenticatedRequest, @Param('id') id: string) {
    return this.otc.approve(req.user.userId, id);
  }

  @Patch('orders/:id/reject')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS, UserRole.SUPPORT)
  reject(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() body: { note?: string },
  ) {
    return this.otc.reject(req.user.userId, id, body.note);
  }
}
