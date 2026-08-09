import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { SetIpoInstrumentDto } from './dto/set-ipo-instrument.dto';
import { CreateIpoDto } from './dto/create-ipo.dto';
import { UpdateIpoStatusDto } from './dto/update-ipo-status.dto';
import { AllocateIpoDto } from './dto/allocate-ipo.dto';

import { IpoService } from './ipo.service';

@Controller('admin/ipo')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminIpoController {
  constructor(private readonly ipoService: IpoService) {}

  @Post()
  create(@Body() dto: CreateIpoDto) {
    return this.ipoService.create(dto);
  }

  @Get()
  list() {
    return this.ipoService.list();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.ipoService.findOne(id);
  }

  @Patch(':id/status')
  updateStatus(@Param('id') id: string, @Body() dto: UpdateIpoStatusDto) {
    return this.ipoService.updateStatus(id, dto);
  }

  @Patch(':id/instrument')
  setInstrument(@Param('id') id: string, @Body() dto: SetIpoInstrumentDto) {
    return this.ipoService.setInstrument(id, dto.instrumentId);
  }

  @Patch('application/:id/allocate')
  allocate(@Param('id') id: string, @Body() dto: AllocateIpoDto) {
    return this.ipoService.allocate(id, dto.quantity, dto.price);
  }
}
