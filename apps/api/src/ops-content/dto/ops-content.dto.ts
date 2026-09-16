import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { Type } from 'class-transformer';
import { AnnouncementType, AppClientPlatform } from '../../generated/prisma/enums';

const LOCALE = /^(en|hi)$/i;
const VERSION = /^\d{1,4}(\.\d{1,4}){0,3}$/;
const SLUG = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export class UpsertInsightArticleDto {
  @IsString()
  @Matches(SLUG)
  @MaxLength(120)
  slug: string;

  @IsString()
  @Matches(LOCALE)
  locale: string = 'en';

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  summary?: string | null;

  @IsString()
  @MinLength(1)
  @MaxLength(200_000)
  body: string;

  @IsOptional()
  @ValidateIf((_, v) => v != null && String(v).trim() !== '')
  @IsUrl({ require_tld: false })
  @MaxLength(2000)
  imageUrl?: string | null;

  @IsOptional()
  @IsBoolean()
  isPublished?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  sortOrder?: number;

  @IsOptional()
  @IsDateString()
  publishedAt?: string | null;
}

export class UpsertAnnouncementDto {
  @IsString()
  @Matches(LOCALE)
  locale: string = 'en';

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title: string;

  @IsString()
  @MinLength(1)
  @MaxLength(50_000)
  body: string;

  @IsOptional()
  @IsEnum(AnnouncementType)
  type?: AnnouncementType;

  @IsOptional()
  @IsBoolean()
  isPublished?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  priority?: number;

  @IsOptional()
  @IsDateString()
  startsAt?: string | null;

  @IsOptional()
  @IsDateString()
  endsAt?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  sortOrder?: number;
}

export class UpsertAppClientSettingDto {
  @IsOptional()
  @IsEnum(AppClientPlatform)
  platform?: AppClientPlatform;

  @IsString()
  @Matches(VERSION)
  @MaxLength(32)
  minVersion: string;

  @IsString()
  @Matches(VERSION)
  @MaxLength(32)
  latestVersion: string;

  @IsOptional()
  @IsBoolean()
  forceUpdate?: boolean;

  @IsOptional()
  @IsBoolean()
  maintenanceMode?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  maintenanceMessage?: string | null;

  @IsOptional()
  @ValidateIf((_, v) => v != null && String(v).trim() !== '')
  @IsUrl({ require_tld: false })
  @MaxLength(2000)
  supportUrl?: string | null;
}
