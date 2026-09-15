import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Matches, Min } from 'class-validator';

export class UpdateLiveQuoteDto {
  @IsString()
  @Matches(/^(?!0+(?:\.0{1,4})?$)\d+(?:\.\d{1,4})?$/, {
    message: 'lastPrice must be a positive price with up to 4 decimals',
  })
  lastPrice!: string;

  @IsOptional()
  @IsString()
  @Matches(/^(?!0+(?:\.0{1,4})?$)\d+(?:\.\d{1,4})?$/, {
    message: 'bidPrice must be a positive price with up to 4 decimals',
  })
  bidPrice?: string;

  @IsOptional()
  @IsString()
  @Matches(/^(?!0+(?:\.0{1,4})?$)\d+(?:\.\d{1,4})?$/, {
    message: 'askPrice must be a positive price with up to 4 decimals',
  })
  askPrice?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  volume?: number;
}
