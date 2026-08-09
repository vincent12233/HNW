import { Controller, Get, Patch, Body } from '@nestjs/common';

import { MarketDataService } from './market-data.service';


@Controller('market-data')
export class MarketDataController {


  constructor(
    private readonly marketDataService:MarketDataService,
  ){}



  @Get()
  getSnapshot(){

    return this.marketDataService
      .getMarketSnapshot();

  }



  @Patch('quote')
  updateQuote(
    @Body()
    body:{
      symbol:string;
      price:string;
      volume?:string;
    }
  ){

    return this.marketDataService
      .updateQuote(
        body.symbol,
        body.price,
        body.volume,
      );

  }


}