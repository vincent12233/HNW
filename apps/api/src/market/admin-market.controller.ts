import {
  Body,
  Controller,
  Get,
  Param,
  ParseEnumPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Exchange } from '../generated/prisma/client';
import { UpdateLiveQuoteDto } from './dto/update-live-quote.dto';
import { MarketService } from './market.service';
import { ListAdminInstrumentsQueryDto } from './dto/list-admin-instruments-query.dto';
import { UpdateInstrumentStatusDto } from './dto/update-instrument-status.dto';
import { CreateInstrumentDto } from './dto/create-instrument.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('admin/market')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminMarketController {
  constructor(private readonly marketService: MarketService) {}

  @Post('instruments')
  createInstrument(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateInstrumentDto,
  ) {
    return this.marketService.createInstrument(request.user.userId, dto);
  }

  @Get('instruments')
  listInstruments(@Query() query: ListAdminInstrumentsQueryDto) {
    return this.marketService.listAdminInstruments(query);
  }

  @Get('instruments/:instrumentId')
  getInstrument(@Param('instrumentId') instrumentId: string) {
    return this.marketService.getAdminInstrument(instrumentId);
  }

  @Patch('instruments/:instrumentId/status')
  updateInstrumentStatus(
    @Req() request: AuthenticatedRequest,
    @Param('instrumentId') instrumentId: string,
    @Body() dto: UpdateInstrumentStatusDto,
  ) {
    return this.marketService.updateInstrumentStatus(
      request.user.userId,
      instrumentId,
      dto,
    );
  }

  @Post('seed')
  seedLiveMarket() {
    return this.marketService.seedLiveMarket();
  }

  @Patch('quotes/:exchange/:symbol')
  updateLiveQuote(
    @Param('exchange', new ParseEnumPipe(Exchange))
    exchange: Exchange,
    @Param('symbol') symbol: string,
    @Body() dto: UpdateLiveQuoteDto,
  ) {
    return this.marketService.updateLiveQuote(exchange, symbol, dto);
  }
}
