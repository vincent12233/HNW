import {
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { IpoService } from './ipo.service';
interface AuthenticatedRequest extends Request {
  user: {
    userId: string;
    phone?: string | null;
    role: string;
  };
}

@Controller('ipo')
@UseGuards(JwtAuthGuard)
export class ClientIpoController {
  constructor(private readonly ipoService: IpoService) {}

  @Get('open')
  listOpenIpos() {
    return this.ipoService.listOpenIpos();
  }

  @Post(':ipoId/apply')
  apply(@Req() request: AuthenticatedRequest, @Param('ipoId') ipoId: string) {
    return this.ipoService.apply(request.user.userId, ipoId);
  }

  @Get('applications/me')
  listMyApplications(@Req() request: AuthenticatedRequest) {
    return this.ipoService.listMyApplications(request.user.userId);
  }

  @Get(':ipoId/application-limit')
  getApplicationLimit(
    @Req() request: AuthenticatedRequest,
    @Param('ipoId') ipoId: string,
  ) {
    return this.ipoService.getApplicationLimit(request.user.userId, ipoId);
  }

  @Get('debts/me')
  getMyDebts(@Req() request: AuthenticatedRequest) {
    return this.ipoService.listMyDebts(request.user.userId);
  }

}
