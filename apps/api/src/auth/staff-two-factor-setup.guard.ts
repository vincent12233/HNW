import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { AuthenticatedRequest } from './authenticated-request';
import { UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

type SetupPayload = {
  sub?: string;
  role?: string;
  version?: number;
  purpose?: string;
};

const STAFF_ROLES = new Set([
  'ADMIN',
  'MANAGER',
  'FINANCE',
  'BUSINESS',
  'SUPPORT',
]);

@Injectable()
export class StaffTwoFactorSetupGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authorization = String(request.headers.authorization ?? '');
    const token = authorization.startsWith('Bearer ')
      ? authorization.slice(7)
      : '';
    if (!token) throw new UnauthorizedException('Setup token is required');

    let payload: SetupPayload;
    try {
      payload = await this.jwt.verifyAsync<SetupPayload>(token);
    } catch {
      throw new UnauthorizedException('Setup token is invalid or expired');
    }
    if (
      payload.purpose !== 'STAFF_2FA_SETUP' ||
      !payload.sub ||
      !payload.role ||
      !STAFF_ROLES.has(payload.role)
    ) {
      throw new UnauthorizedException('Invalid staff setup token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        id: true,
        role: true,
        status: true,
        authVersion: true,
        businessProfile: { select: { isActive: true } },
        twoFactor: { select: { enabled: true } },
      },
    });
    if (
      !user ||
      user.status !== UserStatus.ACTIVE ||
      user.role !== payload.role ||
      user.authVersion !== payload.version ||
      user.twoFactor?.enabled ||
      (user.role === 'BUSINESS' && !user.businessProfile?.isActive)
    ) {
      throw new UnauthorizedException('Staff setup access has been revoked');
    }

    request.user = { userId: user.id, role: user.role };
    return true;
  }
}
