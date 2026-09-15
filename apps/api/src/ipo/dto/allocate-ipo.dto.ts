import { IsInt, IsString, Matches, Max, Min } from 'class-validator';

export class AllocateIpoDto {
  @IsInt()
  @Min(1)
  @Max(1_000_000)
  quantity!: number;

  @IsString()
  @Matches(/^(?!0+(?:\.0{1,2})?$)\d+(?:\.\d{1,2})?$/, {
    message: 'price must be a positive monetary string with up to 2 decimals',
  })
  price!: string;
}
