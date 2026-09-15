import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class KycAccessGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest();
    const authorization = String(request.headers.authorization ?? '');
    const token = authorization.startsWith('Bearer ')
      ? authorization.slice(7)
      : '';
    if (!token) throw new UnauthorizedException('KYC access token is required');

    let payload: any;
    try {
      payload = await this.jwt.verifyAsync(token);
    } catch (_) {
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
      user.role !== 'CLIENT' ||
      user.status === 'DISABLED' ||
      (payload.purpose && !onboarding)
    )
      throw new UnauthorizedException('Invalid KYC access');
    if (!onboarding && user.status !== 'ACTIVE') {
      throw new UnauthorizedException('User account is not active');
    }
    request.user = { userId: user.id, role: user.role, onboarding };
    return true;
  }
}
