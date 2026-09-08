import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UserRole } from '../generated/prisma/enums';
import { OperatorService } from './operator.service';

@Controller('operator')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.SUPPORT)
export class OperatorController {
  constructor(private readonly operatorService: OperatorService) {}

  @Get('customers')
  listCustomers() {
    return this.operatorService.listCustomers();
  }

  @Get('customers/:customerId')
  getCustomer(@Param('customerId') customerId: string) {
    return this.operatorService.getCustomer(customerId);
  }
}
