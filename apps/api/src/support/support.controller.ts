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
  updateTags(
    @Param('id') id: string,
    @Body() body: { tags?: string[] },
  ) {
    return this.supportService.updateTags(id, body.tags || []);
  }

  @Get('conversations/:id/messages')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN, UserRole.CLIENT)
  getMessages(@Req() req: any, @Param('id') id: string) {
    return this.supportService.getMessages(id, req.user.userId, req.user.role);
  }

  @Post('messages')
  @Roles(UserRole.SUPPORT, UserRole.ADMIN, UserRole.CLIENT)
  sendMessage(
    @Req() req: any,
    @Body()
    body: {
      conversationId: string;
      content: string;
    },
  ) {
    return this.supportService.sendMessage(
      body.conversationId,

      req.user.userId,

      req.user.role,

      body.content,
    );
  }
}
