import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  Min,
} from 'class-validator';
import {
  Exchange,
  OrderSide,
  OrderType,
  TimeInForce,
} from '../../generated/prisma/client';

export class CreateOrderDto {
  @IsString()
  @Length(8, 100)
  @Matches(/^[A-Za-z0-9._:-]+$/, {
    message: 'clientOrderId contains invalid characters',
  })
  clientOrderId: string;

  @IsEnum(Exchange)
  exchange: Exchange;

  @IsString()
  @Length(1, 30)
  @Matches(/^[A-Za-z0-9.-]+$/, {
    message: 'symbol contains invalid characters',
  })
  symbol: string;

  @IsEnum(OrderSide)
  side: OrderSide;

  @IsEnum(OrderType)
  type: OrderType;

  @IsOptional()
  @IsEnum(TimeInForce)
  timeInForce: TimeInForce = TimeInForce.DAY;

  @IsInt()
  @Min(1)
  @Max(1000000)
  quantity: number;

  @IsOptional()
  @IsString()
  @Matches(/^(?!0+(?:\.0{1,4})?$)\d+(?:\.\d{1,4})?$/, {
    message: 'limitPrice must be a positive price with up to 4 decimals',
  })
  limitPrice?: string;
}
