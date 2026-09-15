import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { AuthenticatedRequest } from '../auth/authenticated-request';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

type KycAccessPayload = {
  sub?: string;
  version?: number;
  purpose?: string;
};

@Injectable()
export class KycAccessGuard implements CanActivate {
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
    if (!token) throw new UnauthorizedException('KYC access token is required');

    let payload: KycAccessPayload;
    try {
      payload = await this.jwt.verifyAsync<KycAccessPayload>(token);
    } catch (_error) {
      throw new UnauthorizedException('KYC access token is invalid or expired');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: String(payload.sub ?? '') },
      select: { id: true, role: true, status: true, authVersion: true },
    });
    if (!user || payload.version !== user.authVersion) {
      throw new UnauthorizedException('KYC access token has been revoked');
    }
    const onboarding = payload.purpose === 'KYC_ONBOARDING';
    if (
      user.role !== UserRole.CLIENT ||
      user.status === UserStatus.DISABLED ||
      (payload.purpose && !onboarding)
    )
      throw new UnauthorizedException('Invalid KYC access');
    if (!onboarding && user.status !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('User account is not active');
    }
    request.user = { userId: user.id, role: user.role, onboarding };
    return true;
  }
}
