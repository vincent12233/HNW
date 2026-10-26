import { Global, Module } from '@nestjs/common';
import { MarketTimeseriesService } from './market-timeseries.service';

@Global()
@Module({
  providers: [MarketTimeseriesService],
  exports: [MarketTimeseriesService],
})
export class MarketTimeseriesModule {}
