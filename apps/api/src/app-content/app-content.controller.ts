import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { AppContentService } from './app-content.service';

@Controller()
export class AppContentController {
  constructor(private readonly service: AppContentService) {}

  @Get('app-content')
  getPublic(@Query('locale') locale = 'en') {
    return this.service.getPublicBundle(locale);
  }

  @Get('admin/app-content')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  listAdmin(@Query('module') module?: string) {
    return this.service.listAdmin(module);
  }

  @Put('admin/app-content')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  upsert(@Body() body: any) {
    return this.service.upsertEntry(body);
  }

  @Post('admin/app-content/bulk')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  bulk(@Body() body: { entries?: any[] }) {
    return this.service.bulkUpsert(body.entries ?? []);
  }

  @Get('admin/app-content/deposit-accounts')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  listAccounts() {
    return this.service.listDepositAccounts(true);
  }

  @Post('admin/app-content/deposit-accounts')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  createAccount(@Body() body: any) {
    return this.service.createDepositAccount(body);
  }

  @Patch('admin/app-content/deposit-accounts/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  updateAccount(@Param('id') id: string, @Body() body: any) {
    return this.service.updateDepositAccount(id, body);
  }

  @Patch('admin/app-content/deposit-accounts/:id/status')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  setAccountStatus(
    @Param('id') id: string,
    @Body() body: { isActive: boolean },
  ) {
    return this.service.setDepositAccountStatus(id, body.isActive);
  }

  @Delete('admin/app-content/deposit-accounts/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  deleteAccount(@Param('id') id: string) {
    return this.service.deleteDepositAccount(id);
  }

  @Delete('admin/app-content/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  remove(@Param('id') id: string) {
    return this.service.deleteEntry(id);
  }
}
