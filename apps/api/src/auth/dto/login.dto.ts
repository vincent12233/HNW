import { IsOptional, IsString, Length, Matches, MinLength } from 'class-validator';

export class LoginDto {
  @IsOptional()
  @IsString()
  @Matches(/^(?:\+[1-9]\d{6,14}|(?:91)?[6-9]\d{9})$/)
  phone?: string;

  @IsOptional()
  @IsString()
  @Length(3, 32)
  employeeNo?: string;

  @IsString()
  @MinLength(8)
  password: string;
}
