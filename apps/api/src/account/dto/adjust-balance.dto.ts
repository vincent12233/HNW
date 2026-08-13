import {
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
} from 'class-validator';

export class AdjustBalanceDto {
  @IsString()
  @Matches(/^(?!0+(?:\.0{1,2})?$)\d+(?:\.\d{1,2})?$/, {
    message: 'amount must be a positive monetary string with up to 2 decimals',
  })
  amount: string;

  @IsString()
  @Length(8, 100)
  @Matches(/^[A-Za-z0-9._:-]+$/, {
    message: 'referenceId contains invalid characters',
  })
  referenceId: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
