import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Exchange, UserRole } from '../generated/prisma/enums';
import { WatchlistService } from './watchlist.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string };
}

@Controller('watchlist')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CLIENT)
export class WatchlistController {
  constructor(private readonly watchlist: WatchlistService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest) {
    return this.watchlist.list(request.user.userId);
  }

  @Post()
  add(
    @Req() request: AuthenticatedRequest,
    @Body() body: { symbol: string; exchange?: string },
  ) {
    return this.watchlist.add(
      request.user.userId,
      body.symbol,
      this.exchange(body.exchange),
    );
  }

  @Delete(':symbol')
  remove(
    @Req() request: AuthenticatedRequest,
    @Param('symbol') symbol: string,
    @Query('exchange') exchange?: string,
  ) {
    return this.watchlist.remove(
      request.user.userId,
      symbol,
      this.exchange(exchange),
    );
  }

  private exchange(value?: string) {
    return value?.trim().toUpperCase() === Exchange.BSE
      ? Exchange.BSE
      : Exchange.NSE;
  }
}
