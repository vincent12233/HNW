import { Body, Controller, Get, Patch, Query } from '@nestjs/common';
import { MarketDataHealthService } from './market-data-health.service';
import { MarketDataService } from './market-data.service';

@Controller('market-data')
export class MarketDataController {
  constructor(
    private readonly marketDataService: MarketDataService,
    private readonly marketDataHealth: MarketDataHealthService,
  ) {}

  @Get()
  getSnapshot() {
    return this.marketDataService.getMarketSnapshot();
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
