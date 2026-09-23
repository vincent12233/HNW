import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsDateString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { AppContentModule } from '../../generated/prisma/enums';

const MODULES = Object.values(AppContentModule);

/** Client + admin-console locales currently used in this codebase. */
const LOCALES = ['en', 'hi', 'zh'] as const;

export class UpsertAppContentDto {
  @IsIn(MODULES)
  module: AppContentModule;

  @IsString()
  @MinLength(1)
  @MaxLength(128)
  key: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  title?: string | null;

  @IsString()
  @MaxLength(200_000)
  body: string;

  @IsOptional()
  @IsIn(LOCALES)
  locale?: string;

  @IsOptional()
  metadata?: any;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  sortOrder?: number;
}

export class BulkUpsertAppContentDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => UpsertAppContentDto)
  entries: UpsertAppContentDto[];
}

export class RestoreAppContentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(128)
  revisionId: string;

  @IsDateString()
  expectedUpdatedAt: string;
}
