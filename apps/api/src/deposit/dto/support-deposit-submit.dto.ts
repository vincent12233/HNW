import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class SupportDepositSubmitDto {
  @IsString()
  @MaxLength(64)
  conversationId!: string;

  @IsString()
  @Matches(/^(?!0+(?:\.0{1,2})?$)\d+(?:\.\d{1,2})?$/, {
    message: 'amount must be a positive monetary string with up to 2 decimals',
  })
  amount!: string;

  @IsString()
  @Matches(/^[A-Za-z0-9._:-]{8,100}$/, {
    message: 'referenceId must be 8-100 alphanumeric characters',
  })
  referenceId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  paymentMethod?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
