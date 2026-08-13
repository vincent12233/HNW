import { Module } from '@nestjs/common';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';
import { SupportGateway } from './support.gateway';

@Module({
  controllers: [
    SupportController,
  ],
  providers: [
    SupportService,
    SupportGateway,
  ],
})
export class SupportModule {}
