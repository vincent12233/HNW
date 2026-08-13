import { IsNumber } from 'class-validator';

export class PayIpoDebtDto {
  @IsNumber()
  amount: number;
}