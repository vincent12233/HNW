import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
  NotFoundException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { TeamService } from './team.service';
import { BusinessService } from './business.service';
import { KycService } from '../kyc/kyc.service';
import {
  CreateTeamStaffDto,
  TeamStatusDto,
  TeamActiveDto,
  TeamPasswordDto,
  TeamReviewDto,
} from './team.dto';
import { ListAdminOrdersQueryDto } from '../orders/dto/list-admin-orders-query.dto';
type ActorRequest = { user: { userId: string } };
@Controller('team')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'MANAGER')
export class TeamController {
  constructor(
    private readonly team: TeamService,
    private readonly business: BusinessService,
    private readonly kyc: KycService,
  ) {}
  @Get() list(@Req() req: ActorRequest) {
    return this.team.list(req.user.userId);
  }
  @Post() create(@Req() req: ActorRequest, @Body() dto: CreateTeamStaffDto) {
    return this.team.create(req.user.userId, dto);
  }
  @Delete(':id') remove(@Req() req: ActorRequest, @Param('id') id: string) {
    return this.team.remove(req.user.userId, id);
  }
  @Get(':id/orders')
  @Roles('MANAGER')
  async orders(
    @Req() req: ActorRequest,
    @Param('id') id: string,
    @Query() query: ListAdminOrdersQueryDto,
  ) {
    await this.team.business(req.user.userId, id);
    return this.business.myOrders(id, query);
  }
  @Get(':id/:view')
  @Roles('MANAGER')
  async view(
    @Req() req: ActorRequest,
    @Param('id') id: string,
    @Param('view') view: string,
  ) {
    await this.team.business(req.user.userId, id);
    switch (view) {
      case 'customers':
        return this.business.customersByBusiness(id);
      case 'deposits':
        return this.business.myDeposits(id);
      case 'withdrawals':
        return this.business.myWithdrawals(id);
      case 'positions':
        return this.business.myPositions(id, {});
      case 'trades':
        return this.business.myTradePairs(id);
      case 'kyc':
        return this.kyc.pendingForBusiness(id);
      default:
        throw new NotFoundException();
    }
  }
  @Get(':id/kyc/:submissionId/file')
  @Roles('MANAGER')
  async file(
    @Req() req: ActorRequest,
    @Param('id') id: string,
    @Param('submissionId') submissionId: string,
    @Query('side') side: string,
  ) {
    await this.team.business(req.user.userId, id);
    return this.kyc.fileForBusiness(
      id,
      submissionId,
      ['back', 'selfie', 'signature'].includes(side)
        ? (side as 'back' | 'selfie' | 'signature')
        : 'front',
    );
  }
  @Patch(':id/kyc')
  @Roles('MANAGER')
  async review(
    @Req() req: ActorRequest,
    @Param('id') id: string,
    @Body() dto: TeamReviewDto,
  ) {
    await this.team.business(req.user.userId, id);
    const result = await this.kyc.review(id, dto);
    await this.team.audit(
      req.user.userId,
      dto.submissionId,
      'MANAGER_KYC_REVIEW',
    );
    return result;
  }
  @Patch(':id/customers/:customerId/status')
  @Roles('MANAGER')
  async customerStatus(
    @Req() req: ActorRequest,
    @Param('id') id: string,
    @Param('customerId') customerId: string,
    @Body() dto: TeamStatusDto,
  ) {
    await this.team.business(req.user.userId, id);
    const result = await this.business.updateMyCustomerStatus(
      id,
      customerId,
      dto.status,
    );
    await this.team.audit(
      req.user.userId,
      customerId,
      'MANAGER_CUSTOMER_STATUS',
    );
    return result;
  }
  @Patch(':id/active')
  @Roles('MANAGER')
  async active(
    @Req() req: ActorRequest,
    @Param('id') id: string,
    @Body() dto: TeamActiveDto,
  ) {
    await this.team.business(req.user.userId, id);
    const result = await this.business.setBusinessActive(id, dto.isActive);
    await this.team.audit(req.user.userId, id, 'MANAGER_BUSINESS_STATUS');
    return result;
  }
  @Patch(':id/password')
  @Roles('MANAGER')
  async password(
    @Req() req: ActorRequest,
    @Param('id') id: string,
    @Body() dto: TeamPasswordDto,
  ) {
    await this.team.business(req.user.userId, id);
    const result = await this.business.resetBusinessPassword(
      id,
      dto.newPassword,
    );
    await this.team.audit(req.user.userId, id, 'MANAGER_BUSINESS_PASSWORD');
    return result;
  }
}
