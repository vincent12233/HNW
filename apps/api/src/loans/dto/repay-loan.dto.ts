import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class RepayLoanDto {
  @IsString()
  @Matches(/^(?!0+(?:\.0{1,2})?$)\d+(?:\.\d{1,2})?$/, {
    message: 'amount must be a positive monetary string with up to 2 decimals',
  })
  amount!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
