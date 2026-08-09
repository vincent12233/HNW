import { IsString, Length, Matches, MinLength } from 'class-validator';

export class RegisterDto {
  @IsString()
  @MinLength(8)
  password: string;

  @IsString()
  @Matches(/^(91)?[6-9]\d{9}$/)
  phone: string;

  @IsString()
  @Length(12, 12)
  inviteCode: string;
}
