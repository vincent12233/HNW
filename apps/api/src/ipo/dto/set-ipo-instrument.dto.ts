import { IsString } from 'class-validator';

export class SetIpoInstrumentDto {
  @IsString()
  instrumentId: string;
}
