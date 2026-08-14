import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { InstrumentMasterService } from './instrument-master.service';

@Controller('admin/instruments')
@UseGuards(JwtAuthGuard, RolesGuard)
export class InstrumentMasterController {
  constructor(private readonly instruments: InstrumentMasterService) {}

  @Get()
  @Roles(UserRole.ADMIN, UserRole.SUPPORT, UserRole.FINANCE)
  list(
    @Query('search') search?: string,
    @Query('active') active?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.instruments.list({
      search,
      active:
        active === undefined
          ? undefined
          : active.trim().toLowerCase() === 'true',
      page: Number.parseInt(page ?? '1', 10) || 1,
      pageSize: Number.parseInt(pageSize ?? '50', 10) || 50,
    });
  }

  @Post('sync/nse')
  @Roles(UserRole.ADMIN)
  syncNse() {
    return this.instruments.syncNseEquities();
  }

  @Patch('bulk-status')
  @Roles(UserRole.ADMIN)
  setBulkStatus(
    @Body() body: { symbols?: string[]; isActive?: boolean },
  ) {
    return this.instruments.setBulkActive(
      Array.isArray(body.symbols) ? body.symbols : [],
      body.isActive === true,
    );
  }

  @Patch(':instrumentId/status')
  @Roles(UserRole.ADMIN)
  setStatus(
    @Param('instrumentId') instrumentId: string,
    @Body() body: { isActive?: boolean },
  ) {
    return this.instruments.setActive(instrumentId, body.isActive === true);
  }
}
