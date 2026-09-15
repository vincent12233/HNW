import type { Request } from 'express';

import type { UserRole } from '../generated/prisma/enums';

export type AuthUser = {
  userId: string;
  phone?: string | null;
  role: UserRole;
};

export type AuthenticatedRequest = Request & {
  user: AuthUser;
};

declare global {
  // Passport stores JwtStrategy.validate() return value on request.user
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    // eslint-disable-next-line @typescript-eslint/no-empty-object-type
    interface User extends AuthUser {}
  }
}

export {};
