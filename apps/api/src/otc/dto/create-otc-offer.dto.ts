import {
  IsDateString,
  IsNotEmpty,
  IsString,
  Matches,
} from 'class-validator';

export class CreateOtcOfferDto {
  @IsString()
  @IsNotEmpty()
  instrumentId!: string;

  /** Contractual discounted settlement price (not the live market quote). */
  @IsString()
  @Matches(/^(?!0+(?:\.0{1,4})?$)\d+(?:\.\d{1,4})?$/, {
    message: 'price must be a positive monetary string with up to 4 decimals',
  })
  price!: string;

  @IsDateString()
  validFrom!: string;

  @IsDateString()
  validUntil!: string;
}
