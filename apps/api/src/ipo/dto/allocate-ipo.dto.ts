import { IsInt, IsNumber, Max, Min } from 'class-validator';

export class AllocateIpoDto {
  @IsInt()
  @Min(1)
  @Max(1_000_000)
  quantity: number;

  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0.0001)
  @Max(100_000_000)
  price: number;
}
