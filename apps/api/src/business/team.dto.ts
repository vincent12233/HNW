import { Transform } from 'class-transformer';
import { IsBoolean, IsIn, IsOptional, IsString, Length, Matches, MaxLength } from 'class-validator';
export class CreateTeamStaffDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim().toUpperCase() : value)
  @IsString() @Matches(/^[A-Z0-9_-]{3,32}$/) employeeNo: string;
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @Length(2,100) fullName: string;
  @IsString() @Length(12,72) password: string;
}
export class TeamStatusDto {
  @IsIn(['ACTIVE','SUSPENDED','DISABLED']) status: 'ACTIVE'|'SUSPENDED'|'DISABLED';
}
export class TeamActiveDto { @IsBoolean() isActive: boolean; }
export class TeamPasswordDto { @IsString() @Length(12,72) newPassword: string; }
export class TeamReviewDto {
  @IsString() submissionId: string;
  @IsIn(['APPROVED','REJECTED']) decision: 'APPROVED'|'REJECTED';
  @IsOptional() @IsString() @MaxLength(1000) note?: string;
}
