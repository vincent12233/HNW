import { Body, Controller, Post, Req } from '@nestjs/common';
import type { Request } from 'express';

import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

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
}
