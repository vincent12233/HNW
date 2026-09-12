import { IsEnum } from 'class-validator';

export enum IpoStatus {
  DRAFT = 'DRAFT',
  PUBLISHED = 'PUBLISHED',
  OPEN = 'OPEN',
  CLOSED = 'CLOSED',
  ALLOTMENT_DONE = 'ALLOTMENT_DONE',
}

export class UpdateIpoStatusDto {
  @IsEnum(IpoStatus)
  status: IpoStatus;
}
