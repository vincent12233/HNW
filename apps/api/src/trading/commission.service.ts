import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';

@Injectable()
export class CommissionService {
  calculateFees(_grossAmount: Prisma.Decimal) {
    // Preserve the current trading behaviour: fees are zero until a
    // configurable brokerage/tax schedule is introduced.
    return new Prisma.Decimal(0);
  }
}
