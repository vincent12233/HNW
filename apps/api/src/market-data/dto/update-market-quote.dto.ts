import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class UpdateMarketQuoteDto {
  @IsString()
  @Matches(/^[A-Za-z0-9.-]{1,30}$/, {
    message: 'symbol contains invalid characters',
  })
  symbol!: string;

  @IsString()
  @Matches(/^(?!0+(?:\.0{1,4})?$)\d+(?:\.\d{1,4})?$/, {
    message: 'price must be a positive price with up to 4 decimals',
  })
  price!: string;

  @IsOptional()
  @IsString()
  @Matches(/^\d+$/, {
    message: 'volume must be a non-negative integer string',
  })
  @MaxLength(24)
  volume?: string;
}
