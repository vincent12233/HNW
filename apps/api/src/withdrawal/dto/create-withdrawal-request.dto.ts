import { Type } from 'class-transformer';
import {
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  Matches,
} from 'class-validator';

export class CreateWithdrawalRequestDto {
  @IsString()
  @Matches(/^\d{6}$/)
  withdrawalPin!: string;

  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false, maxDecimalPlaces: 2 })
  @Min(100)
  @Max(9_999_999_999_999.99)
  amount!: number;

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
