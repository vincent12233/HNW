import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { KycService } from './kyc.service';
import { KycAccessGuard } from './kyc-access.guard';

@Controller('kyc')
export class KycController {
  constructor(private readonly kycService: KycService) {}

  @Post('submit')
  @UseGuards(KycAccessGuard)
  submit(
    @Req() req: any,
    @Body()
    body: {
      documentType: 'AADHAAR' | 'PAN';
      fileName: string;
      mimeType?: string;
      contentBase64: string;
      backFileName?: string;
      backMimeType?: string;
      backContentBase64?: string;
    },
  ) {
    return this.kycService.submit(req.user.userId, body);
  }

  @Get('business/pending')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.BUSINESS)
  pendingForBusiness(@Req() req: any) {
    return this.kycService.pendingForBusiness(req.user.userId);
  }

  @Get('business/:submissionId/file')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.BUSINESS)
  fileForBusiness(@Req() req: any, @Param('submissionId') submissionId: string, @Query('side') side?: string) {
    return this.kycService.fileForBusiness(req.user.userId, submissionId, side === 'back' ? 'back' : 'front');
  }

  @Get('status')
  @UseGuards(KycAccessGuard)
  status(@Req() req: any) {
    return this.kycService.status(req.user.userId);
  }

  @Patch('business/review')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.BUSINESS)
  review(
    @Req() req: any,
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
