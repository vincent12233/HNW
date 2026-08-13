import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';
import { Exchange, InstrumentType } from '../../generated/prisma/client';

export class CreateInstrumentDto {
  @IsEnum(Exchange)
  exchange: Exchange;

  @IsString()
  @Matches(/^[A-Za-z0-9.-]+$/, {
    message: 'symbol contains invalid characters',
  })
  symbol: string;

  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  isin?: string;

  @IsOptional()
  @IsString()
  logoUrl?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000000)
  displayOrder: number = 0;

  @IsEnum(InstrumentType)
  type: InstrumentType;

  @IsOptional()
  @IsString()
  currency: string = 'INR';

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1000000)
  lotSize: number = 1;

  @IsString()
  @Matches(/^(?!0+(?:\.0{1,4})?$)\d+(?:\.\d{1,4})?$/, {
    message: 'tickSize must be a positive value with up to 4 decimals',
  })
  tickSize: string;

  @IsString()
  @Matches(/^(?!0+(?:\.0{1,4})?$)\d+(?:\.\d{1,4})?$/, {
    message: 'lastPrice must be a positive price with up to 4 decimals',
  })
  lastPrice: string;

  @IsOptional()
  @IsString()
  bidPrice?: string;

  @IsOptional()
  @IsString()
  askPrice?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  volume: number = 0;
}
