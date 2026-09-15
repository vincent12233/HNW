import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { SetIpoInstrumentDto } from './dto/set-ipo-instrument.dto';
import { CreateIpoDto } from './dto/create-ipo.dto';
import { UpdateIpoPricingDto } from './dto/update-ipo-pricing.dto';
import { UpdateIpoStatusDto } from './dto/update-ipo-status.dto';
import { AllocateIpoDto } from './dto/allocate-ipo.dto';

import { IpoService } from './ipo.service';

@Controller('admin/ipo')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminIpoController {
  constructor(private readonly ipoService: IpoService) {}

  @Post()
  @Roles('ADMIN')
  create(@Body() dto: CreateIpoDto) {
    return this.ipoService.create(dto);
  }

  @Post('applications/publish')
  @Roles('ADMIN')
  publish(@Req() req: any, @Body() body: { ids: string[] }) {
    return this.ipoService.publish(body.ids, req.user.userId);
  }

  @Get()
  @Roles('ADMIN')
  list() {
    return this.ipoService.list();
  }

  @Get('debts')
  @Roles('ADMIN', 'FINANCE', 'BUSINESS')
  listDebts(@Req() req: any, @Query('search') search?: string) {
    return this.ipoService.listDebts(req.user.userId, req.user.role, search);
  }

  @Get(':id')
  @Roles('ADMIN')
  findOne(@Param('id') id: string) {
    return this.ipoService.findOne(id);
  }

  @Patch(':id/status')
  @Roles('ADMIN')
  updateStatus(@Param('id') id: string, @Body() dto: UpdateIpoStatusDto) {
    return this.ipoService.updateStatus(id, dto);
  }

  @Patch(':id/instrument')
  @Roles('ADMIN')
  setInstrument(@Param('id') id: string, @Body() dto: SetIpoInstrumentDto) {
    return this.ipoService.setInstrument(id, dto.instrumentId);
  }

  /** Edit subscription/settlement price and/or offer window (super-admin). */
  @Patch(':id')
  @Roles('ADMIN')
  updatePricing(@Param('id') id: string, @Body() dto: UpdateIpoPricingDto) {
    return this.ipoService.updatePricing(id, dto);
  }

  @Patch('application/:id/allocate')
  @Roles('ADMIN')
  allocate(@Param('id') id: string, @Body() dto: AllocateIpoDto) {
    return this.ipoService.allocate(id, dto.quantity, dto.price);
  }
}
