import { Type } from 'class-transformer';
import { IsInt, IsString, Matches, Max, Min } from 'class-validator';

export class SubmitOtcOrderDto {
  @IsString()
  offerId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1_000_000)
  quantity!: number;

  @IsString()
  @Matches(/^\d{4}$/, {
    message: 'transactionKey must be a 4-digit OTC key',
  })
  transactionKey!: string;
}
