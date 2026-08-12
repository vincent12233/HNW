import { Module } from '@nestjs/common';
import { InstrumentMasterController } from './instrument-master.controller';
import { InstrumentMasterService } from './instrument-master.service';

@Module({
  controllers: [InstrumentMasterController],
  providers: [InstrumentMasterService],
  exports: [InstrumentMasterService],
})
export class InstrumentMasterModule {}
