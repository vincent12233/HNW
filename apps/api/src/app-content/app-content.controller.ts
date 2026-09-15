import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import {
  AppContentService,
  type AppContentUpsertInput,
} from './app-content.service';

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
  upsert(@Body() body: AppContentUpsertInput) {
    return this.service.upsertEntry(body);
  }

  @Post('admin/app-content/bulk')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  bulk(@Body() body: { entries?: AppContentUpsertInput[] }) {
    return this.service.bulkUpsert(body.entries ?? []);
  }

  @Delete('admin/app-content/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  remove(@Param('id') id: string) {
    return this.service.deleteEntry(id);
  }
}
