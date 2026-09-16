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
import {
  UpsertAnnouncementDto,
  UpsertAppClientSettingDto,
  UpsertInsightArticleDto,
} from './dto/ops-content.dto';
import { AnnouncementsService } from './announcements.service';
import { AppClientSettingsService } from './app-client-settings.service';
import { InsightArticlesService } from './insight-articles.service';

@Controller()
export class OpsContentController {
  constructor(
    private readonly insights: InsightArticlesService,
    private readonly announcements: AnnouncementsService,
    private readonly settings: AppClientSettingsService,
  ) {}

  // ---- Public ----
  @Get('insights')
  listInsights(@Query('locale') locale = 'en') {
    return this.insights.listPublic(locale);
  }

  @Get('insights/:slug')
  getInsight(@Param('slug') slug: string, @Query('locale') locale = 'en') {
    return this.insights.getPublicBySlug(slug, locale);
  }

  @Get('announcements')
  listAnnouncements(@Query('locale') locale = 'en') {
    return this.announcements.listPublic(locale);
  }

  @Get('app-settings')
  getAppSettings(@Query('platform') platform = 'WEB') {
    return this.settings.getPublic(platform);
  }

  // ---- Admin Insights ----
  @Get('admin/insights')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminListInsights() {
    return this.insights.listAdmin();
  }

  @Post('admin/insights')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminCreateInsight(
    @Req() request: AuthenticatedRequest,
    @Body() body: UpsertInsightArticleDto,
  ) {
    return this.insights.create(body, {
      userId: request.user.userId,
      role: request.user.role,
    });
  }

  @Put('admin/insights/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminUpdateInsight(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() body: UpsertInsightArticleDto,
  ) {
    return this.insights.update(id, body, {
      userId: request.user.userId,
      role: request.user.role,
    });
  }

  @Delete('admin/insights/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminDeleteInsight(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
  ) {
    return this.insights.remove(id, {
      userId: request.user.userId,
      role: request.user.role,
    });
  }

  // ---- Admin Announcements ----
  @Get('admin/announcements')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminListAnnouncements() {
    return this.announcements.listAdmin();
  }

  @Post('admin/announcements')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminCreateAnnouncement(
    @Req() request: AuthenticatedRequest,
    @Body() body: UpsertAnnouncementDto,
  ) {
    return this.announcements.create(body, {
      userId: request.user.userId,
      role: request.user.role,
    });
  }

  @Put('admin/announcements/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminUpdateAnnouncement(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() body: UpsertAnnouncementDto,
  ) {
    return this.announcements.update(id, body, {
      userId: request.user.userId,
      role: request.user.role,
    });
  }

  @Delete('admin/announcements/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminDeleteAnnouncement(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
  ) {
    return this.announcements.remove(id, {
      userId: request.user.userId,
      role: request.user.role,
    });
  }

  // ---- Admin App Settings ----
  @Get('admin/app-settings')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminListSettings() {
    return this.settings.listAdmin();
  }

  @Put('admin/app-settings/:platform')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminUpsertSettings(
    @Req() request: AuthenticatedRequest,
    @Param('platform') platform: string,
    @Body() body: UpsertAppClientSettingDto,
  ) {
    const normalized = platform.trim().toUpperCase();
    return this.settings.upsert(
      {
        ...body,
        platform: normalized as import('../generated/prisma/enums').AppClientPlatform,
      },
      { userId: request.user.userId, role: request.user.role },
    );
  }
}
