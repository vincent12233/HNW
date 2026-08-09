import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';

export class ListPositionsQueryDto {
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]+$/, {
    message: 'exchange contains invalid characters',
  })
  exchange?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z0-9.-]+$/, {
    message: 'symbol contains invalid characters',
  })
  symbol?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize: number = 20;
}
