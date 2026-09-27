import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { SubmitClientErrorDto } from './dto/submit-client-error.dto';
import { ErrorIngestionService } from './error-ingestion.service';

@Controller('observability')
export class ErrorIngestionController {
  constructor(private readonly service: ErrorIngestionService) {}

  @Post('client-errors')
  @HttpCode(202)
  submit(@Body() input: SubmitClientErrorDto) {
    return this.service.accept(input);
  }
}
