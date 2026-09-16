import {
  ExecutionContext,
  ForbiddenException,
  Inject,
  Injectable,
  Optional,
} from '@nestjs/common';
import { AuthGuard, AuthModuleOptions } from '@nestjs/passport';

import type { AuthenticatedRequest } from './authenticated-request';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  // Nest 12 resolves subclass ctor metadata; re-declare optional options so
  // feature modules do not require a local PassportModule import.
  constructor(
    @Optional() @Inject(AuthModuleOptions) options?: AuthModuleOptions,
  ) {
    super(options);
  }

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
