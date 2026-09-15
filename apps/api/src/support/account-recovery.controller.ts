import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AccountRecoveryService } from './account-recovery.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('auth/recovery')
export class AccountRecoveryController {
  constructor(private readonly service: AccountRecoveryService) {}
  @Post('open') open(@Body() body: { phone: string }) {
    return this.service.open(body.phone);
  }
  @Get('messages') messages(@Headers('x-recovery-token') token: string) {
    return this.service.messages(token || '');
  }
  @Post('messages') send(
    @Headers('x-recovery-token') token: string,
    @Body() body: { content: string },
  ) {
    return this.service.send(token || '', body.content);
  }
  @Post('reset') reset(
    @Headers('x-recovery-token') token: string,
    @Body() body: { code: string; newPassword: string },
  ) {
    return this.service.reset(token || '', body.code, body.newPassword);
  }
}

@Controller('support/recovery')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.SUPPORT, UserRole.ADMIN)
export class StaffRecoveryController {
  constructor(private readonly service: AccountRecoveryService) {}
  @Get() list() {
    return this.service.list();
  }
  @Get(':id/messages') messages(@Param('id') id: string) {
    return this.service.staffMessages(id);
  }
  @Post(':id/messages') send(
    @Param('id') id: string,
    @Body() body: { content: string },
  ) {
    return this.service.staffSend(id, body.content);
  }
  @Post(':id/issue') issue(
    @Param('id') id: string,
    @Req() req: AuthenticatedRequest,
    @Body() body: { identityVerified: boolean },
  ) {
    return this.service.issue(id, req.user.userId, body.identityVerified);
  }
}
