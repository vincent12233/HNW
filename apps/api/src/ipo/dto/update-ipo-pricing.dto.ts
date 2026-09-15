import { IsDateString, IsOptional, IsString, Matches } from 'class-validator';

export class UpdateIpoPricingDto {
  /** Internal subscription / settlement price — editable by super-admin before applications exist. */
  @IsOptional()
  @IsString()
  @Matches(/^(?!0+(?:\.0{1,2})?$)\d+(?:\.\d{1,2})?$/, {
    message:
      'issuePrice must be a positive monetary string with up to 2 decimals',
  })
  issuePrice?: string;

  @IsOptional()
  @IsDateString()
  openDate?: string;

  @IsOptional()
  @IsDateString()
  closeDate?: string;
}
