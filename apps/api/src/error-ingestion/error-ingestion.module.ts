import { Module } from '@nestjs/common';
import { ErrorIngestionController } from './error-ingestion.controller';
import { ErrorIngestionService } from './error-ingestion.service';

@Module({
  controllers: [ErrorIngestionController],
  providers: [ErrorIngestionService],
})
export class ErrorIngestionModule {}
