import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import type { AuthenticatedRequest } from '../auth/authenticated-request';
import { UserRole } from '../generated/prisma/enums';
import { AppContentService } from './app-content.service';
import {
  BulkUpsertAppContentDto,
  UpsertAppContentDto,
} from './dto/upsert-app-content.dto';

/**
 * Platform-wide CMS.
 * Effective platform administrator role = UserRole.ADMIN
 * (Admin UI label: 超级管理员). No SUPER_ADMIN / PLATFORM_ADMIN enum exists.
 */
@Controller()
export class AppContentController {
  constructor(private readonly service: AppContentService) {}

  /** Public client bundle — unauthenticated read-only. */
  @Get('app-content')
  getPublic(@Query('locale') locale = 'en') {
    return this.service.getPublicBundle(locale);
  }

  /**
   * Support-desk tags / quick replies (ADMIN + SUPPORT read).
   * Not part of the public Flutter bundle.
   */
  @Get('support/desk-content')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPPORT)
  getSupportDesk(@Query('locale') locale = 'zh') {
    return this.service.getSupportDeskContent(locale);
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
  upsert(
    @Req() request: AuthenticatedRequest,
    @Body() body: UpsertAppContentDto,
  ) {
    return this.service.upsertEntry(body, {
      userId: request.user.userId,
      role: request.user.role,
    });
  }

  @Post('admin/app-content/bulk')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  bulk(
    @Req() request: AuthenticatedRequest,
    @Body() body: BulkUpsertAppContentDto,
  ) {
    return this.service.bulkUpsert(body.entries ?? [], {
      userId: request.user.userId,
      role: request.user.role,
    });
  }

  @Delete('admin/app-content/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  remove(@Req() request: AuthenticatedRequest, @Param('id') id: string) {
    return this.service.deleteEntry(id, {
      userId: request.user.userId,
      role: request.user.role,
    });
  }
}
