import {
  Body,
  Controller,
  Get,
  Patch,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { MarketSessionService } from '../market-session/market-session.service';
import { HistoricalMarketDataService } from './historical-market-data.service';
import { MarketDataHealthService } from './market-data-health.service';
import { MarketDataService } from './market-data.service';
import { MarketNewsService } from './market-news.service';
import { UpdateMarketQuoteDto } from './dto/update-market-quote.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('market-data')
export class MarketDataController {
  constructor(
    private readonly marketDataService: MarketDataService,
    private readonly marketDataHealth: MarketDataHealthService,
    private readonly historicalMarketData: HistoricalMarketDataService,
    private readonly marketSession: MarketSessionService,
    private readonly marketNews: MarketNewsService,
  ) {}

  @Get()
  getSnapshot() {
    return this.marketDataService.getMarketSnapshot();
  }

  @Get('home')
  @UseGuards(JwtAuthGuard)
  getHomeBootstrap(
    @Req() request: AuthenticatedRequest,
    @Query('symbols') symbols = '',
    @Query('limit') limit = '40',
  ) {
    return this.marketDataService.getHomeBootstrap(
      request.user.userId,
      symbols,
      Number(limit),
    );
  }

  @Get('search')
  searchSnapshot(
    @Query('q') query = '',
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '50',
  ) {
    return this.marketDataService.searchMarketSnapshot(
      query,
      Number(page),
      Number(pageSize),
    );
  }

  @Get('history')
  getHistory(
    @Query('symbol') symbol = '',
    @Query('range') range = '1D',
    @Query('exchange') exchange = '',
  ) {
    return this.historicalMarketData.getHistory(symbol, range, exchange);
  }

  @Get('indices')
  getIndexSnapshot() {
    return this.marketDataService.getIndexSnapshot();
  }

  @Get('news')
  getNews(@Query('limit') limit = '8') {
    return this.marketNews.latest(Number(limit));
  }

  @Get('institutional')
  @UseGuards(JwtAuthGuard)
  getInstitutionalOffers() {
    return this.marketDataService.getInstitutionalOffers();
  }

  @Get('session')
  getMarketSession() {
    return this.marketSession.getStatus();
  }

  @Get('health')
  async getHealth() {
    return {
      ...this.marketDataHealth.getStatus(),
      ...(await this.marketDataHealth.getPersistedDiagnostics()),
    };
  }

  @Patch('quote')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  updateQuote(@Body() body: UpdateMarketQuoteDto) {
    return this.marketDataService.updateQuote(
      body.symbol,
      body.price,
      body.volume,
    );
  }
}
