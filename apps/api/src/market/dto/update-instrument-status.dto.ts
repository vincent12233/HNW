import { IsBoolean } from 'class-validator';

export class UpdateInstrumentStatusDto {
  @IsBoolean()
  isActive: boolean;
}
