import { IsInt, IsNumber, Min } from 'class-validator';

export class AllocateIpoDto {
  @IsInt()
  @Min(1)
  quantity: number;

  @IsNumber()
  @Min(0)
  price: number;
}
