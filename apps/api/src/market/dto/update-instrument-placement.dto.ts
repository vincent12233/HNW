import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  Max,
  Min,
} from 'class-validator';

/** Placement-only update — does not change catalog identity, quotes, or tradability rules. */
export class UpdateInstrumentPlacementDto {
  @IsOptional()
  @IsBoolean()
  featuredHome?: boolean;

  @IsOptional()
  @IsBoolean()
  featuredMarkets?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  displayOrder?: number;
}
