import {
  Controller,
  Post,
  Get,
  Req,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { SupportService } from './support.service';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';

@Controller('support')
@UseGuards(JwtAuthGuard, RolesGuard)
export class SupportController {
  constructor(private readonly supportService: SupportService) {}

  @Post('conversations')
  createConversation(@Req() req: any) {
    return this.supportService.createConversation(req.user.userId);
  }

  @Get('conversations')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN)
  listConversations() {
    return this.supportService.listOpenConversations();
  }

  @Get('conversations/me')
  myConversations(@Req() req: any) {
    return this.supportService.listClientConversations(req.user.userId);
  }

  @Post('conversations/:id/tags')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN)
  updateTags(@Param('id') id: string, @Body() body: { tags?: string[] }) {
    return this.supportService.updateTags(id, body.tags || []);
  }

  @Post('conversations/:id/meta')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN)
  updateMeta(
    @Req() req: any,
    @Param('id') id: string,
    @Body()
    body: {
      internalNote?: string;
      priority?: string;
      status?: 'OPEN' | 'CLOSED';
    },
  ) {
    return this.supportService.updateMeta(id, body, req.user.userId);
  }

  @Get('conversations/:id/messages')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN, UserRole.CLIENT)
  getMessages(@Req() req: any, @Param('id') id: string) {
    return this.supportService.getMessages(id, req.user.userId, req.user.role);
  }

  @Post('conversations/:id/read')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN, UserRole.CLIENT)
  markRead(@Req() req: any, @Param('id') id: string) {
    return this.supportService.markRead(id, req.user.userId, req.user.role);
  }

  @Get('unread-count')
  unreadCount(@Req() req: any) {
    return this.supportService.unreadCount(req.user.userId, req.user.role);
  }

  @Get('status')
  status() {
    return this.supportService.status();
  }

  @Post('conversations/:id/assign')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN)
  assign(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { assignedToId?: string },
  ) {
    return this.supportService.assign(
      id,
      body.assignedToId || req.user.userId,
      req.user.userId,
    );
  }

  @Post('conversations/:id/reopen')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN)
  reopen(@Req() req: any, @Param('id') id: string) {
    return this.supportService.reopen(id, req.user.userId);
  }

  @Post('messages')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN, UserRole.CLIENT)
  sendMessage(
    @Req() req: any,
    @Body()
    body: {
      conversationId: string;
      content: string;
      attachmentName?: string;
      attachmentType?: string;
      attachmentBase64?: string;
    },
  ) {
    return this.supportService.sendMessage(
      body.conversationId,

      req.user.userId,

      req.user.role,

      body.content,
      body.attachmentName,
      body.attachmentType,
      body.attachmentBase64,
    );
  }

  @Post('translate')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN)
  translateMessage(@Body() body: { content?: string }) {
    return this.supportService.translateMessage(body.content || '');
  }
}
