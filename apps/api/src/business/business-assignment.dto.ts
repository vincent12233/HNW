import { Transform } from 'class-transformer';
import {
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

function trimString(value: unknown) {
  return typeof value === 'string' ? value.trim() : value;
}

function emptyToNull(value: unknown) {
  if (value === '' || value === undefined) return null;
  return typeof value === 'string' ? value.trim() : value;
}

export class PreviewBusinessAssignmentDto {
  @Transform(({ value }: { value: unknown }) => trimString(value))
  @IsUUID()
  businessUserId: string;

  @Transform(({ value }: { value: unknown }) => trimString(value))
  @IsUUID()
  newManagerId: string;
}

export class TransferBusinessAssignmentDto {
  @Transform(({ value }: { value: unknown }) => trimString(value))
  @IsUUID()
  businessUserId: string;

  @Transform(({ value }: { value: unknown }) => trimString(value))
  @IsUUID()
  newManagerId: string;

  @Transform(({ value }: { value: unknown }) => trimString(value))
  @IsString()
  @MinLength(4)
  @MaxLength(240)
  reason: string;

  @Transform(({ value }: { value: unknown }) => emptyToNull(value))
  @ValidateIf((_, value) => value !== null)
  @IsUUID()
  expectedCurrentManagerId: string | null;

  @Transform(({ value }: { value: unknown }) => trimString(value))
  @IsString()
  @MinLength(8)
  @MaxLength(80)
  idempotencyKey: string;
}

export class ListBusinessAssignmentsQueryDto {
  @IsOptional()
  @Transform(({ value }: { value: unknown }) => trimString(value))
  @IsString()
  @MaxLength(80)
  search?: string;

  @IsOptional()
  @Transform(({ value }: { value: unknown }) => trimString(value))
  @IsString()
  @MaxLength(64)
  managerId?: string;
}
