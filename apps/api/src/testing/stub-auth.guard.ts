import { CanActivate, ExecutionContext } from '@nestjs/common';
import type { AuthenticatedRequest } from '../auth/authenticated-request';
import { UserRole } from '../generated/prisma/enums';

export function stubAuthenticatedUser(user: {
  userId: string;
  role: UserRole;
  onboarding?: boolean;
}): CanActivate {
  return {
    canActivate(context: ExecutionContext) {
      const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
      request.user = {
        userId: user.userId,
        role: user.role,
        onboarding: user.onboarding,
      };
      return true;
    },
  };
}
