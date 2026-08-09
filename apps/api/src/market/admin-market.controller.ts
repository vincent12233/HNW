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
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Exchange } from '../generated/prisma/client';
import { UpdateSandboxQuoteDto } from './dto/update-sandbox-quote.dto';
import { MarketService } from './market.service';
import { ListAdminInstrumentsQueryDto } from './dto/list-admin-instruments-query.dto';
import { UpdateInstrumentStatusDto } from './dto/update-instrument-status.dto';
import { CreateInstrumentDto } from './dto/create-instrument.dto';
interface AuthenticatedRequest extends Request {
  user: {
    userId: string;
    phone?: string | null;
    role: string;
  };
}

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
  seedSandboxMarket() {
    return this.marketService.seedSandboxMarket();
  }

  @Patch('quotes/:exchange/:symbol')
  updateSandboxQuote(
    @Param('exchange', new ParseEnumPipe(Exchange))
    exchange: Exchange,
    @Param('symbol') symbol: string,
    @Body() dto: UpdateSandboxQuoteDto,
  ) {
    return this.marketService.updateSandboxQuote(exchange, symbol, dto);
  }
}
