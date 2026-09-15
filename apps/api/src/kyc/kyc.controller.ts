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
import { UserRole } from '../generated/prisma/enums';
import { KycService } from './kyc.service';
import type { KycSubmissionInput } from './kyc.service';
import { KycAccessGuard } from './kyc-access.guard';
import { DedicatedOperatorScopeGuard } from '../business/dedicated-operator-scope.guard';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('kyc')
export class KycController {
  constructor(private readonly kycService: KycService) {}

  @Post('submit')
  @UseGuards(KycAccessGuard)
  submit(
    @Req() req: AuthenticatedRequest,
    @Body()
    body: KycSubmissionInput,
  ) {
    return this.kycService.submit(req.user.userId, body);
  }

  @Get('business/pending')
  @UseGuards(JwtAuthGuard, RolesGuard, DedicatedOperatorScopeGuard)
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  pendingForBusiness(@Req() req: AuthenticatedRequest) {
    return this.kycService.pendingForBusiness(req.user.userId);
  }

  @Get('business/:submissionId/file')
  @UseGuards(JwtAuthGuard, RolesGuard, DedicatedOperatorScopeGuard)
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  fileForBusiness(
    @Req() req: AuthenticatedRequest,
    @Param('submissionId') submissionId: string,
    @Query('side') side?: string,
  ) {
    return this.kycService.fileForBusiness(
      req.user.userId,
      submissionId,
      side === 'selfie' || side === 'signature' || side === 'back'
        ? side
        : 'front',
    );
  }

  @Get('status')
  @UseGuards(KycAccessGuard)
  status(@Req() req: AuthenticatedRequest) {
    return this.kycService.status(req.user.userId);
  }

  @Patch('business/review')
  @UseGuards(JwtAuthGuard, RolesGuard, DedicatedOperatorScopeGuard)
  @Roles(UserRole.BUSINESS, UserRole.SUPPORT)
  review(
    @Req() req: AuthenticatedRequest,
    @Body()
    body: {
      submissionId: string;
      decision: 'APPROVED' | 'REJECTED';
      note?: string;
    },
  ) {
    return this.kycService.review(req.user.userId, body);
  }
}
