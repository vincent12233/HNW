import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
export class InvitePoolDto {
  @IsInt() @Min(1) @Max(100) count: number;
}
export class CreateTeamStaffDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : '',
  )
  @IsString()
  @Matches(/^[A-Z0-9_-]{3,32}$/)
  employeeNo: string;
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : '',
  )
  @IsString()
  @Length(2, 100)
  fullName: string;
  @IsString() @Length(12, 72) password: string;
}
export class TeamStatusDto {
  @IsIn(['ACTIVE', 'SUSPENDED', 'DISABLED']) status:
    'ACTIVE' | 'SUSPENDED' | 'DISABLED';
}
export class TeamActiveDto {
  @IsBoolean() isActive: boolean;
}
export class TeamPasswordDto {
  @IsString() @Length(12, 72) newPassword: string;
}
export class TeamReviewDto {
  @IsString() submissionId: string;
  @IsIn(['APPROVED', 'REJECTED']) decision: 'APPROVED' | 'REJECTED';
  @IsOptional() @IsString() @MaxLength(1000) note?: string;
}
