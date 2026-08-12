import {
  Body,
  Controller,
  Get,
  Patch,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { HistoricalMarketDataService } from './historical-market-data.service';
import { MarketDataHealthService } from './market-data-health.service';
import { MarketDataService } from './market-data.service';

interface AuthenticatedRequest extends Request {
  user: {
    userId: string;
    phone?: string | null;
    role: string;
  };
}

@Controller('market-data')
export class MarketDataController {
  constructor(
    private readonly marketDataService: MarketDataService,
    private readonly marketDataHealth: MarketDataHealthService,
    private readonly historicalMarketData: HistoricalMarketDataService,
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
  ) {
    return this.historicalMarketData.getHistory(symbol, range);
  }

  @Get('indices')
  getIndexSnapshot() {
    return this.marketDataService.getIndexSnapshot();
  }

  @Get('health')
  getHealth() {
    return this.marketDataHealth.getStatus();
  }

  @Patch('quote')
  updateQuote(
    @Body()
    body: {
      symbol: string;
      price: string;
      volume?: string;
    },
  ) {
    return this.marketDataService.updateQuote(
      body.symbol,
      body.price,
      body.volume,
    );
  }
}
