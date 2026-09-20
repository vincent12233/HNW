import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

function optionalTrim(value: unknown) {
  return typeof value === 'string' ? value.trim() : value;
}

export class UpdateVipTierDto {
  @IsOptional()
  @Transform(({ value }: { value: unknown }) => optionalTrim(value))
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  displayName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  description?: string;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => {
    if (value === null || value === '') return null;
    return typeof value === 'string' || typeof value === 'number'
      ? String(value).trim()
      : value;
  })
  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsString()
  @Matches(/^(0|[1-9]\d*)(\.\d{1,2})?$/, {
    message: 'VIP threshold is invalid',
  })
  minimumCumulativeDeposit?: string | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(40)
  displayOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class AdjustVipClientTierDto {
  @Transform(({ value }: { value: unknown }) => optionalTrim(value))
  @IsString()
  tier: string;

  @Transform(({ value }: { value: unknown }) => optionalTrim(value))
  @IsString()
  @MinLength(4)
  @MaxLength(240)
  reason: string;
}
