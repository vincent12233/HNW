import { Module } from '@nestjs/common';
import { DepositService } from './deposit.service';
import { DepositController } from './deposit.controller';

@Module({
  providers: [DepositService],
  controllers: [DepositController],
})
export class DepositModule {}
