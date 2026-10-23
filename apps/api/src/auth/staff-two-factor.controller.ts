import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import type { AuthenticatedRequest } from './authenticated-request';
import { StaffTwoFactorSetupGuard } from './staff-two-factor-setup.guard';
import { TwoFactorService } from './two-factor.service';

@Controller('auth/staff-two-factor')
@UseGuards(StaffTwoFactorSetupGuard)
export class StaffTwoFactorController {
  constructor(private readonly twoFactor: TwoFactorService) {}

  @Post('setup')
  setup(@Req() req: AuthenticatedRequest) {
    return this.twoFactor.setupVerifiedStaff(req.user.userId);
  }

  @Post('confirm')
  confirm(@Req() req: AuthenticatedRequest, @Body() body: { code?: string }) {
    return this.twoFactor.confirm(req.user.userId, body.code);
  }
}
