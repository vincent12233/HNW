import { IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class RegisterDto {
  @IsString()
  @MinLength(8)
  password: string;

  @IsString()
  @Matches(/^(91)?[6-9]\d{9}$/)
  phone: string;

  @IsString()
  @MinLength(7)
  @MaxLength(20)
  inviteCode: string;
}
