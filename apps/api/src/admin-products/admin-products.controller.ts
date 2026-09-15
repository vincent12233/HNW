import {
  Body,
  Controller,
  Delete,
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
import { AdminProductsService } from './admin-products.service';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('admin-products')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminProductsController {
  constructor(private readonly service: AdminProductsService) {}

  @Get('watchlist')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS, UserRole.SUPPORT)
  watchlist(@Req() request: AuthenticatedRequest) {
    return this.service.listWatchlist(request.user?.role);
  }

  @Post('watchlist')
  @Roles(UserRole.ADMIN)
  createWatchlist(@Body() body: Record<string, unknown>) {
    return this.service.createWatchlist(body);
  }

  @Patch('watchlist/:id/status')
  @Roles(UserRole.ADMIN)
  updateWatchlistStatus(
    @Param('id') id: string,
    @Body() body: { status: string },
  ) {
    return this.service.updateWatchlistStatus(id, body.status);
  }

  @Patch('watchlist/:id')
  @Roles(UserRole.ADMIN)
  updateWatchlist(
    @Param('id') id: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.service.updateWatchlist(id, body);
  }

  @Delete('watchlist/:id')
  @Roles(UserRole.ADMIN)
  deleteWatchlist(@Param('id') id: string) {
    return this.service.deleteWatchlist(id);
  }

  @Get('block-trades')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS, UserRole.SUPPORT)
  blockTrades(@Req() request: AuthenticatedRequest) {
    return this.service.listBlockTrades(request.user?.role);
  }

  @Post('block-trades')
  @Roles(UserRole.ADMIN)
  createBlockTrade(@Body() body: Record<string, unknown>) {
    return this.service.createBlockTrade(body);
  }

  @Patch('block-trades/:id/status')
  @Roles(UserRole.ADMIN)
  updateBlockTradeStatus(
    @Param('id') id: string,
    @Body() body: { status: string },
  ) {
    return this.service.updateBlockTradeStatus(id, body.status);
  }

  @Patch('block-trades/:id')
  @Roles(UserRole.ADMIN)
  updateBlockTrade(
    @Param('id') id: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.service.updateBlockTrade(id, body);
  }

  @Delete('block-trades/:id')
  @Roles(UserRole.ADMIN)
  deleteBlockTrade(@Param('id') id: string) {
    return this.service.deleteBlockTrade(id);
  }

  @Get('funds')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS, UserRole.SUPPORT)
  funds() {
    return this.service.listFunds();
  }

  @Post('funds')
  @Roles(UserRole.ADMIN)
  createFund(@Body() body: Record<string, unknown>) {
    return this.service.createFund(body);
  }

  @Patch('funds/:id/status')
  @Roles(UserRole.ADMIN)
  updateFundStatus(@Param('id') id: string, @Body() body: { status: string }) {
    return this.service.updateFundStatus(id, body.status);
  }

  @Patch('funds/:id')
  @Roles(UserRole.ADMIN)
  updateFund(@Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.service.updateFund(id, body);
  }

  @Delete('funds/:id')
  @Roles(UserRole.ADMIN)
  deleteFund(@Param('id') id: string) {
    return this.service.deleteFund(id);
  }

  @Get('quant')
  @Roles(UserRole.ADMIN, UserRole.BUSINESS, UserRole.SUPPORT)
  quant() {
    return this.service.listQuant();
  }

  @Post('quant')
  @Roles(UserRole.ADMIN)
  createQuant(@Body() body: Record<string, unknown>) {
    return this.service.createQuant(body);
  }

  @Patch('quant/:id/status')
  @Roles(UserRole.ADMIN)
  updateQuantStatus(@Param('id') id: string, @Body() body: { status: string }) {
    return this.service.updateQuantStatus(id, body.status);
  }

  @Patch('quant/:id')
  @Roles(UserRole.ADMIN)
  updateQuant(@Param('id') id: string, @Body() body: Record<string, unknown>) {
    return this.service.updateQuant(id, body);
  }

  @Delete('quant/:id')
  @Roles(UserRole.ADMIN)
  deleteQuant(@Param('id') id: string) {
    return this.service.deleteQuant(id);
  }
}
