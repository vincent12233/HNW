import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import type { Request } from 'express';

import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

interface JwtPayload {
  sub: string;
  role: string;
  version?: number;
  purpose?: string;
}

const backendRoles = new Set([
  'ADMIN',
  'MANAGER',
  'FINANCE',
  'BUSINESS',
  'SUPPORT',
]);

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        ExtractJwt.fromAuthHeaderAsBearerToken(),
        (request: Request) => {
          const cookie = request?.headers?.cookie ?? '';
          const backendRole = request
            .header('x-backend-role')
            ?.trim()
            .toUpperCase();
          const cookieName =
            backendRole && backendRoles.has(backendRole)
              ? `staff_access_${backendRole.toLowerCase()}`
              : 'staff_access';
          const match = cookie.match(
            new RegExp(`(?:^|;\\s*)${cookieName}=([^;]+)`),
          );
          return match ? decodeURIComponent(match[1]) : null;
        },
      ]),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('JWT_SECRET'),
    });
  }

  async validate(payload: JwtPayload) {
    if (!payload.sub || payload.purpose) {
      throw new UnauthorizedException('Invalid access token');
    }

    const user = await this.prisma.user.findUnique({
      where: {
        id: payload.sub,
      },
      select: {
        id: true,
        role: true,
        status: true,
        authVersion: true,
        deletedAt: true,

        businessProfile: {
          select: {
            isActive: true,
          },
        },
      },
    });

    if (!user) {
      throw new UnauthorizedException('User account not found');
    }

    if (user.deletedAt || user.status !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('User account is not active');
    }

    if (payload.version !== user.authVersion) {
      throw new UnauthorizedException('Access token has been revoked');
    }

    if (
      user.role === UserRole.BUSINESS &&
      (!user.businessProfile || !user.businessProfile.isActive)
    ) {
      throw new UnauthorizedException('Business account has been disabled');
    }

    return {
      userId: user.id,
      role: user.role,
    };
  }
}
