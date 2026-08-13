import { Controller, Get, Param, ParseEnumPipe, Query } from '@nestjs/common';
import { Exchange } from '../generated/prisma/client';
import { ListInstrumentsQueryDto } from './dto/list-instruments-query.dto';
import { MarketService } from './market.service';

@Controller('market')
export class MarketController {
  constructor(private readonly marketService: MarketService) {}

  @Get('instruments')
  listInstruments(@Query() query: ListInstrumentsQueryDto) {
    return this.marketService.listInstruments(query);
  }

  @Get('instruments/:exchange/:symbol')
  getInstrument(
    @Param('exchange', new ParseEnumPipe(Exchange)) exchange: Exchange,
    @Param('symbol') symbol: string,
  ) {
    return this.marketService.getInstrument(exchange, symbol);
  }

  @Get('quotes/:exchange/:symbol')
  getQuote(
    @Param('exchange', new ParseEnumPipe(Exchange)) exchange: Exchange,
    @Param('symbol') symbol: string,
  ) {
    return this.marketService.getQuote(exchange, symbol);
  }
}
