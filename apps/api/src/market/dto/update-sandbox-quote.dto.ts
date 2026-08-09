import { Type } from 'class-transformer';
import { IsNumber, IsOptional, IsPositive, Min } from 'class-validator';

export class UpdateSandboxQuoteDto {
  @IsPositive()
  @Type(() => Number)
  lastPrice!: number;

  @IsOptional()
  @IsPositive()
  @Type(() => Number)
  bidPrice?: number;

  @IsOptional()
  @IsPositive()
  @Type(() => Number)
  askPrice?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  volume?: number;
}
