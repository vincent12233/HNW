import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsOptional,
  IsString,
  Matches,
} from 'class-validator';

export class UpdateOtcOfferDto {
  @IsOptional()
  @IsString()
  @Matches(/^(?!0+(?:\.0{1,4})?$)\d+(?:\.\d{1,4})?$/, {
    message: 'price must be a positive monetary string with up to 4 decimals',
  })
  price?: string;

  @IsOptional()
  @IsDateString()
  validFrom?: string;

  @IsOptional()
  @IsDateString()
  validUntil?: string;

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isActive?: boolean;
}
