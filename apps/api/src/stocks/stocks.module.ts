import { Module } from '@nestjs/common';
import { StocksService } from './stocks.service';
import { StocksController } from './stocks.controller';

@Module({
  providers: [StocksService],
  controllers: [StocksController]
})
export class StocksModule {}
