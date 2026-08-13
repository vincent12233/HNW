import { Type } from 'class-transformer';
import {
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  Max,
  Min,
} from 'class-validator';
import {
  AccountTransactionStatus,
  AccountTransactionType,
} from '../../generated/prisma/client';

export class ListTransactionsQueryDto {
  @IsOptional()
  @IsEnum(AccountTransactionType)
  type?: AccountTransactionType;

  @IsOptional()
  @IsEnum(AccountTransactionStatus)
  status?: AccountTransactionStatus;

  @IsOptional()
  @IsDateString()
  dateFrom?: string;

  @IsOptional()
  @IsDateString()
  dateTo?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize: number = 20;
}
