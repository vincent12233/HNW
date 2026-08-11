import { Body, Controller, Get, Patch } from '@nestjs/common';
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
