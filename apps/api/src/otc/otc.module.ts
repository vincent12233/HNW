import { Module } from '@nestjs/common';
import { OtcController } from './otc.controller';
import { OtcService } from './otc.service';

@Module({ controllers: [OtcController], providers: [OtcService] })
export class OtcModule {}
