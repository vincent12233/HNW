import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { LedgerService } from './ledger.service';

@Controller('admin/ledger')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'FINANCE')
export class LedgerController {
  constructor(private readonly ledger: LedgerService) {}

  @Get('reconciliation')
  reconciliation() {
    return this.ledger.reconciliation();
  }
}
