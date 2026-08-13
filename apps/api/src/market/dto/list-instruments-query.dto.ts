import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { Exchange } from '../../generated/prisma/client';

export class ListInstrumentsQueryDto {
  @IsOptional()
  @IsEnum(Exchange)
  exchange?: Exchange;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}
