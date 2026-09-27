import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class SubmitClientErrorDto {
  @IsIn(['client_error', 'admin_error'])
  event!: 'client_error' | 'admin_error';

  @IsString()
  @MaxLength(256)
  operation!: string;

  @IsString()
  @MaxLength(128)
  error!: string;

  @IsString()
  @MaxLength(64)
  fingerprint!: string;

  @IsString()
  @MaxLength(4000)
  message!: string;

  @IsOptional()
  @IsString()
  @MaxLength(8000)
  stack?: string;

  @IsOptional()
  @IsInt()
  @Min(100)
  @Max(599)
  statusCode?: number;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  requestId?: string;

  @IsString()
  @MaxLength(64)
  timestamp!: string;
}
