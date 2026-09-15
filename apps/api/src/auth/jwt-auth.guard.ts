import {
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

import type { AuthenticatedRequest } from './authenticated-request';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const allowed = (await super.canActivate(context)) as boolean;
    if (!allowed) return false;
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const backendRole = request.header('x-backend-role')?.trim().toUpperCase();
    const backendRoles = new Set([
      'ADMIN',
      'MANAGER',
      'FINANCE',
      'BUSINESS',
      'SUPPORT',
    ]);
    if (
      backendRole &&
      backendRoles.has(backendRole) &&
      request.user?.role !== backendRole
    ) {
      throw new ForbiddenException(
        `This account belongs to the ${request.user?.role} backend.`,
      );
    }
    return true;
  }
}
