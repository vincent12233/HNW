import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';

import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto, @Req() req: Request) {
    const forwardedFor = req.headers['x-forwarded-for'];

    const forwardedIp = Array.isArray(forwardedFor)
      ? forwardedFor[0]
      : forwardedFor?.split(',')[0]?.trim();

    const ipAddress = forwardedIp || req.ip || req.socket.remoteAddress || null;

    const userAgent = req.headers['user-agent'] || null;

    return this.authService.login(dto, {
      ipAddress,
      userAgent,
    });
  }

  @Post('password-reset/request')
  requestPasswordReset(@Body() body: { phone: string }) {
    return this.authService.requestPasswordReset(body.phone);
  }

  @Post('password-reset/confirm')
  confirmPasswordReset(@Body() body: { phone: string; code: string; newPassword: string }) {
    return this.authService.confirmPasswordReset(body.phone, body.code, body.newPassword);
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
