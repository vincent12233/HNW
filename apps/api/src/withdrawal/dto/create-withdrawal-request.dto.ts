import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class CreateWithdrawalRequestDto {
  @IsString()
  @Matches(/^\d{6}$/)
  withdrawalPin!: string;

  @IsString()
  @Matches(/^(?!0+(?:\.0{1,2})?$)\d+(?:\.\d{1,2})?$/, {
    message: 'amount must be a positive monetary string with up to 2 decimals',
  })
  amount!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  bankName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  accountNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  ifscCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  upiId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
