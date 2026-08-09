import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { AdminProductsService } from './admin-products.service';

@Controller('admin-products')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminProductsController {
  constructor(private readonly service: AdminProductsService) {}

  @Get('watchlist')
  watchlist() {
    return this.service.listWatchlist();
  }

  @Post('watchlist')
  createWatchlist(@Body() body: any) {
    return this.service.createWatchlist(body);
  }

  @Patch('watchlist/:id/status')
  updateWatchlistStatus(@Param('id') id: string, @Body() body: { status: string }) {
    return this.service.updateWatchlistStatus(id, body.status);
  }

  @Patch('watchlist/:id')
  updateWatchlist(@Param('id') id: string, @Body() body: any) {
    return this.service.updateWatchlist(id, body);
  }

  @Delete('watchlist/:id')
  deleteWatchlist(@Param('id') id: string) {
    return this.service.deleteWatchlist(id);
  }

  @Get('block-trades')
  blockTrades() {
    return this.service.listBlockTrades();
  }

  @Post('block-trades')
  createBlockTrade(@Body() body: any) {
    return this.service.createBlockTrade(body);
  }

  @Patch('block-trades/:id/status')
  updateBlockTradeStatus(@Param('id') id: string, @Body() body: { status: string }) {
    return this.service.updateBlockTradeStatus(id, body.status);
  }

  @Patch('block-trades/:id')
  updateBlockTrade(@Param('id') id: string, @Body() body: any) {
    return this.service.updateBlockTrade(id, body);
  }

  @Delete('block-trades/:id')
  deleteBlockTrade(@Param('id') id: string) {
    return this.service.deleteBlockTrade(id);
  }

  @Get('funds')
  funds() {
    return this.service.listFunds();
  }

  @Post('funds')
  createFund(@Body() body: any) {
    return this.service.createFund(body);
  }

  @Patch('funds/:id/status')
  updateFundStatus(@Param('id') id: string, @Body() body: { status: string }) {
    return this.service.updateFundStatus(id, body.status);
  }

  @Patch('funds/:id')
  updateFund(@Param('id') id: string, @Body() body: any) {
    return this.service.updateFund(id, body);
  }

  @Delete('funds/:id')
  deleteFund(@Param('id') id: string) {
    return this.service.deleteFund(id);
  }

  @Get('quant')
  quant() {
    return this.service.listQuant();
  }

  @Post('quant')
  createQuant(@Body() body: any) {
    return this.service.createQuant(body);
  }

  @Patch('quant/:id/status')
  updateQuantStatus(@Param('id') id: string, @Body() body: { status: string }) {
    return this.service.updateQuantStatus(id, body.status);
  }

  @Patch('quant/:id')
  updateQuant(@Param('id') id: string, @Body() body: any) {
    return this.service.updateQuant(id, body);
  }

  @Delete('quant/:id')
  deleteQuant(@Param('id') id: string) {
    return this.service.deleteQuant(id);
  }
}
