import {
  IsDateString,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

export class CreateLoanDto {
  @IsString()
  @MaxLength(64)
  accountNumber!: string;

  @IsString()
  @Matches(/^(?!0+(?:\.0{1,2})?$)\d+(?:\.\d{1,2})?$/, {
    message: 'amount must be a positive monetary string with up to 2 decimals',
  })
  amount!: string;

  @IsOptional()
  @IsString()
  @Matches(/^(?:\d+)(?:\.\d{1,2})?$/, {
    message: 'interestRate must be a non-negative rate with up to 2 decimals',
  })
  interestRate?: string;

  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
