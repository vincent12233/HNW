import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Request, Response } from 'express';

import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAuthGuard } from './jwt-auth.guard';

const backendRoles = new Set([
  'ADMIN',
  'MANAGER',
  'FINANCE',
  'BUSINESS',
  'SUPPORT',
]);
const staffSessionSeconds = 365 * 24 * 60 * 60;

function staffCookieName(role?: string) {
  const normalized = role?.trim().toUpperCase();
  return normalized && backendRoles.has(normalized)
    ? `staff_access_${normalized.toLowerCase()}`
    : 'staff_access';
}

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  async login(
    @Body() dto: LoginDto,
    @Req() req: Request,
    @Res({ passthrough: true }) response: Response,
  ) {
    const forwardedFor = req.headers['x-forwarded-for'];

    const forwardedIp = Array.isArray(forwardedFor)
      ? forwardedFor[0]
      : forwardedFor?.split(',')[0]?.trim();

    const ipAddress = forwardedIp || req.ip || req.socket.remoteAddress || null;

    const userAgent = req.headers['user-agent'] || null;

    const result = await this.authService.login(dto, {
      ipAddress,
      userAgent,
    });
    const backendRole = req.header('x-backend-role')?.trim().toUpperCase();
    if (
      backendRole &&
      backendRoles.has(backendRole) &&
      result.user.role !== backendRole
    ) {
      response.status(403);
      return {
        message: `This account belongs to the ${result.user.role} backend.`,
      };
    }
    // Browser staff consoles use an HttpOnly cookie. Non-browser verification
    // and operational clients retain the Bearer-token response contract.
    if (dto.employeeNo && result.user.role !== 'CLIENT' && req.headers.origin) {
      response.cookie(staffCookieName(backendRole), result.accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: process.env.NODE_ENV === 'production' ? 'none' : 'lax',
        maxAge: staffSessionSeconds * 1000,
        path: '/',
      });
      return {
        ...result,
        accessToken: undefined,
        expiresIn: staffSessionSeconds,
      };
    }
    return result;
  }

  @Post('logout')
  logout(@Req() req: Request, @Res({ passthrough: true }) response: Response) {
    const cookieOptions = {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: process.env.NODE_ENV === 'production' ? 'none' : 'lax',
      path: '/',
    } as const;
    response.clearCookie(
      staffCookieName(req.header('x-backend-role')),
      cookieOptions,
    );
    response.clearCookie('staff_access', cookieOptions);
    return { loggedOut: true };
  }

  @Post('password-reset/request')
  requestPasswordReset(@Body() body: { phone: string }) {
    return this.authService.requestPasswordReset(body.phone);
  }

  @Post('password-reset/confirm')
  confirmPasswordReset(
    @Body() body: { phone: string; code: string; newPassword: string },
  ) {
    return this.authService.confirmPasswordReset(
      body.phone,
      body.code,
      body.newPassword,
    );
  }

  @Post('google')
  google(@Body() body: { idToken: string }) {
    return this.authService.googleLogin(body.idToken);
  }

  @Post('google/link')
  @UseGuards(JwtAuthGuard)
  linkGoogle(@Req() req: any, @Body() body: { idToken: string }) {
    return this.authService.linkGoogle(req.user.userId, body.idToken);
  }

  @Post('biometric/token')
  @UseGuards(JwtAuthGuard)
  biometricToken(@Req() req: any) {
    return this.authService.createBiometricToken(req.user.userId);
  }

  @Post('biometric/login')
  biometricLogin(@Body() body: { biometricToken: string }) {
    return this.authService.biometricLogin(body.biometricToken);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@Req() req: any) {
    return this.authService.currentUser(req.user.userId);
  }
}
