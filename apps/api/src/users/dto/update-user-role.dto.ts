import { IsEnum } from 'class-validator';
import { UserRole } from '../../generated/prisma/client';

export class UpdateUserRoleDto {
  @IsEnum(UserRole)
  role: UserRole;
}
