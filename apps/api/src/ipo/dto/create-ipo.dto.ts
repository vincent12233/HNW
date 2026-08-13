import {
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsString,
} from 'class-validator';

import { Exchange } from '../../generated/prisma/client';

export class CreateIpoDto {
  @IsString()
  symbol: string;

  @IsString()
  companyName: string;

  @IsEnum(Exchange)
  exchange: Exchange;

  @IsString()
  instrumentId: string;

  @IsNumber()
  issuePrice: number;

  @IsInt()
  lotSize: number;

  @IsInt()
  totalShares: number;

  @IsDateString()
  openDate: string;

  @IsDateString()
  closeDate: string;
}
