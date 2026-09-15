import {
  IsDateString,
  IsEnum,
  IsInt,
  IsString,
  Matches,
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

  @IsString()
  @Matches(/^(?!0+(?:\.0{1,2})?$)\d+(?:\.\d{1,2})?$/, {
    message:
      'issuePrice must be a positive monetary string with up to 2 decimals',
  })
  issuePrice: string;

  @IsInt()
  lotSize: number;

  @IsInt()
  totalShares: number;

  @IsDateString()
  openDate: string;

  @IsDateString()
  closeDate: string;
}
