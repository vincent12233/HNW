import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { randomBytes, randomInt } from 'crypto';
import axios from 'axios';

import {
  InviteCodeStatus,
  UserRole,
  UserStatus,
} from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';

import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto) {
    const phone = this.normalizeIndianPhone(dto.phone);

    if (!phone) {
      throw new BadRequestException('Invalid Indian mobile number');
    }

    const email = this.phoneEmail(phone);
    const inviteCodeValue = dto.inviteCode.trim().toUpperCase();

    const existingUser = await this.usersService.findByPhone(phone);

    if (existingUser) {
      throw new ConflictException('Phone number is already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);
    const accountNumber = this.generateAccountNumber();
    const customerNo = this.generateCustomerNo();

    const result = await this.prisma.$transaction(async (tx) => {
      const inviteCode = await tx.inviteCode.findUnique({
        where: {
          code: inviteCodeValue,
        },
        include: {
          businessProfile: {
            select: {
              userId: true,
              isActive: true,
            },
          },
        },
      });

      if (!inviteCode) {
        throw new BadRequestException('Invalid invite code');
      }

      if (inviteCode.status === InviteCodeStatus.USED) {
        throw new BadRequestException('Invite code has already been used');
      }

      if (inviteCode.status === InviteCodeStatus.DISABLED) {
        throw new BadRequestException('Invite code is disabled');
      }

      if (
        inviteCode.status === InviteCodeStatus.EXPIRED ||
        (inviteCode.expiresAt && inviteCode.expiresAt.getTime() <= Date.now())
      ) {
        if (inviteCode.status !== InviteCodeStatus.EXPIRED) {
          await tx.inviteCode.update({
            where: {
              id: inviteCode.id,
            },
            data: {
              status: InviteCodeStatus.EXPIRED,
            },
          });
        }

        throw new BadRequestException('Invite code has expired');
      }

      if (!inviteCode.businessProfile.isActive) {
        throw new BadRequestException(
          'The associated business account is inactive',
        );
      }

      const claimedInviteCode = await tx.inviteCode.updateMany({
        where: {
          id: inviteCode.id,
          status: InviteCodeStatus.UNUSED,
          customerId: null,
        },
        data: {
          status: InviteCodeStatus.USED,
          usedAt: new Date(),
        },
      });

      if (claimedInviteCode.count !== 1) {
        throw new BadRequestException('Invite code has already been used');
      }

      const user = await tx.user.create({
        data: {
          email,
          passwordHash,
          fullName: this.defaultCustomerName(phone),
          phone,
          role: UserRole.CLIENT,
          status: UserStatus.SUSPENDED,
          assignedBusinessId: inviteCode.businessProfile.userId,
          account: {
            create: {
              accountNumber,
              currency: 'INR',
              isLive: true,
              cashBalance: 0,
              buyingPower: 0,
            },
          },
        },
        include: {
          account: true,
        },
      });

      await tx.$executeRaw`
        UPDATE "users"
        SET "customerNo" = ${customerNo}
        WHERE "id" = ${user.id}
      `;

      await tx.inviteCode.update({
        where: {
          id: inviteCode.id,
        },
        data: {
          customerId: user.id,
        },
      });

      return user;
    });

    return {
      message: 'Registration successful',
      user: {
        id: result.id,
        fullName: result.fullName,
        phone: result.phone,
        role: result.role,
        status: result.status,
        createdAt: result.createdAt,
      },
    };
  }

  async login(
    dto: LoginDto,
    context?: {
      ipAddress?: string | null;
      userAgent?: string | null;
    },
  ) {
    const phone = dto.phone ? this.normalizeIndianPhone(dto.phone) : null;
    const employeeNo = dto.employeeNo?.trim().toUpperCase();

    if (!phone && !employeeNo) {
      throw new UnauthorizedException('Invalid account or password');
    }

    const user = phone
      ? await this.usersService.findByPhone(phone)
      : await this.usersService.findByEmployeeNo(employeeNo!);

    if (!user) {
      throw new UnauthorizedException('Invalid account or password');
    }

    const passwordMatches = await bcrypt.compare(
      dto.password,
      user.passwordHash,
    );

    if (!passwordMatches) {
      await this.prisma.loginAudit.create({
        data: {
          userId: user.id,
          ipAddress: context?.ipAddress || null,
          userAgent: context?.userAgent || null,
          success: false,
        },
      });

      throw new UnauthorizedException('Invalid account or password');
    }

    if (user.status !== UserStatus.ACTIVE) {
      await this.prisma.loginAudit.create({
        data: {
          userId: user.id,
          ipAddress: context?.ipAddress || null,
          userAgent: context?.userAgent || null,
          success: false,
        },
      });

      if (user.role === UserRole.CLIENT && user.status === UserStatus.SUSPENDED) {
        throw new UnauthorizedException('KYC pending approval');
      }

      throw new UnauthorizedException('User account is not active');
    }

    if (
      user.role === UserRole.BUSINESS &&
      (!user.businessProfile || !user.businessProfile.isActive)
    ) {
      await this.prisma.loginAudit.create({
        data: {
          userId: user.id,
          ipAddress: context?.ipAddress || null,
          userAgent: context?.userAgent || null,
          success: false,
        },
      });

      throw new UnauthorizedException('该业务员账号已被停用');
    }

    await this.prisma.loginAudit.create({
      data: {
        userId: user.id,
        ipAddress: context?.ipAddress || null,
        userAgent: context?.userAgent || null,
        success: true,
      },
    });

    await this.prisma.userDevice.create({
      data: {
        userId: user.id,
        deviceName: (context?.userAgent || 'Mobile device').slice(0, 80),
        platform: this.devicePlatform(context?.userAgent),
        lastIp: context?.ipAddress || null,
      },
    });

    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
      phone: user.phone,
      role: user.role,
      version: user.authVersion,
    });

    return {
      message: 'Login successful',
      accessToken,
      tokenType: 'Bearer',
      expiresIn: 3600,
      user: {
        id: user.id,
        fullName: user.fullName,
        phone: user.phone,
        role: user.role,
        status: user.status,
      },
      account: user.account,
    };
  }

  async requestPasswordReset(phoneValue: string) {
    const phone = this.normalizeIndianPhone(phoneValue || '');
    if (!phone) throw new BadRequestException('Invalid Indian mobile number');
    const user = await this.prisma.user.findFirst({ where: { phone, status: UserStatus.ACTIVE } });
    if (!user) return { sent: true };
    const recentRequests = await this.prisma.passwordResetCode.count({
      where: { userId: user.id, createdAt: { gte: new Date(Date.now() - 15 * 60 * 1000) } },
    });
    if (recentRequests >= 3) {
      throw new HttpException('Too many reset requests. Try again later.', HttpStatus.TOO_MANY_REQUESTS);
    }
    await this.prisma.passwordResetCode.updateMany({ where: { userId: user.id, usedAt: null }, data: { usedAt: new Date() } });
    const code = String(randomInt(100000, 1000000));
    const reset = await this.prisma.passwordResetCode.create({ data: { userId: user.id, codeHash: await bcrypt.hash(code, 12), expiresAt: new Date(Date.now() + 10 * 60 * 1000) } });
    const webhook = this.config.get<string>('SMS_OTP_WEBHOOK_URL')?.trim();
    if (!webhook) throw new BadRequestException('Password reset service is temporarily unavailable');
    const webhookToken = this.config.get<string>('SMS_OTP_WEBHOOK_TOKEN')?.trim();
    try {
      await axios.post(
        webhook,
        { phone: `91${phone}`, message: `Your India Trading password reset code is ${code}. It expires in 10 minutes.` },
        { timeout: 10000, headers: webhookToken ? { Authorization: `Bearer ${webhookToken}` } : undefined },
      );
    } catch {
      await this.prisma.passwordResetCode.update({ where: { id: reset.id }, data: { usedAt: new Date() } });
      throw new BadRequestException('Password reset service is temporarily unavailable');
    }
    return { sent: true };
  }

  async confirmPasswordReset(phoneValue: string, code: string, newPassword: string) {
    const phone = this.normalizeIndianPhone(phoneValue || '');
    if (!phone || !/^\d{6}$/.test(code || '') || String(newPassword || '').length < 8) throw new BadRequestException('Invalid password reset details');
    const user = await this.prisma.user.findFirst({ where: { phone } });
    if (!user) throw new BadRequestException('Invalid or expired reset code');
    const reset = await this.prisma.passwordResetCode.findFirst({ where: { userId: user.id, usedAt: null, expiresAt: { gt: new Date() }, attempts: { lt: 5 } }, orderBy: { createdAt: 'desc' } });
    if (!reset || !(await bcrypt.compare(code, reset.codeHash))) {
      if (reset) await this.prisma.passwordResetCode.update({ where: { id: reset.id }, data: { attempts: { increment: 1 } } });
      throw new BadRequestException('Invalid or expired reset code');
    }
    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id: user.id }, data: { passwordHash: await bcrypt.hash(newPassword, 12), authVersion: { increment: 1 } } }),
      this.prisma.passwordResetCode.update({ where: { id: reset.id }, data: { usedAt: new Date() } }),
      this.prisma.notification.create({ data: { userId: user.id, type: 'SECURITY', title: 'Password changed', body: 'Your account password was reset successfully.' } }),
    ]);
    return { changed: true };
  }

  async googleLogin(idToken: string) {
    const { subject, email } = await this.verifyGoogleToken(idToken);
    const user = await this.prisma.user.findFirst({ where: { OR: [{ googleSubject: subject }, { email }] }, include: { account: true } });
    if (!user || user.status !== UserStatus.ACTIVE) throw new UnauthorizedException('Google account is not linked to an active trading account');
    if (!user.googleSubject) await this.prisma.user.update({ where: { id: user.id }, data: { googleSubject: subject } });
    const accessToken = await this.jwtService.signAsync({ sub: user.id, phone: user.phone, role: user.role, version: user.authVersion });
    return { message: 'Login successful', accessToken, tokenType: 'Bearer', expiresIn: 3600, user: { id: user.id, fullName: user.fullName, phone: user.phone, role: user.role, status: user.status }, account: user.account };
  }

  async linkGoogle(userId: string, idToken: string) {
    const { subject, email } = await this.verifyGoogleToken(idToken);
    const conflict = await this.prisma.user.findFirst({ where: { googleSubject: subject, id: { not: userId } } });
    if (conflict) throw new ConflictException('Google account is already linked');
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('Account not found');
    if (user.email.toLowerCase() !== email) throw new BadRequestException('Google email must match the email saved in Personal Information');
    await this.prisma.user.update({ where: { id: userId }, data: { googleSubject: subject } });
    return { linked: true, email };
  }

  private async verifyGoogleToken(idToken: string) {
    if (!idToken?.trim()) throw new BadRequestException('Google ID token is required');
    const response = await axios.get('https://oauth2.googleapis.com/tokeninfo', { params: { id_token: idToken }, timeout: 10000 });
    const subject = String(response.data?.sub || '');
    const email = String(response.data?.email || '').toLowerCase();
    const audience = String(response.data?.aud || '');
    const clientId = this.config.get<string>('GOOGLE_CLIENT_ID')?.trim();
    if (!subject || !email || !clientId || audience !== clientId || response.data?.email_verified !== 'true') throw new UnauthorizedException('Google account could not be verified');
    return { subject, email };
  }

  async createBiometricToken(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { authVersion: true } });
    if (!user) throw new UnauthorizedException('Account not found');
    const token = await this.jwtService.signAsync(
      { sub: userId, purpose: 'BIOMETRIC_LOGIN', version: user.authVersion },
      { expiresIn: '30d' },
    );
    return { biometricToken: token, expiresIn: 2592000 };
  }

  async biometricLogin(token: string) {
    let payload: any;
    try { payload = await this.jwtService.verifyAsync(token); } catch { throw new UnauthorizedException('Biometric quick login has expired'); }
    if (payload?.purpose !== 'BIOMETRIC_LOGIN' || !payload?.sub) throw new UnauthorizedException('Invalid biometric quick login');
    const user = await this.prisma.user.findUnique({ where: { id: payload.sub }, include: { account: true } });
    if (!user || user.status !== UserStatus.ACTIVE || payload.version !== user.authVersion) throw new UnauthorizedException('Biometric quick login must be enabled again');
    const accessToken = await this.jwtService.signAsync({ sub: user.id, phone: user.phone, role: user.role, version: user.authVersion });
    return { message: 'Login successful', accessToken, tokenType: 'Bearer', expiresIn: 3600, user: { id: user.id, fullName: user.fullName, phone: user.phone, role: user.role, status: user.status }, account: user.account };
  }

  private generateAccountNumber(): string {
    const suffix = randomBytes(5).toString('hex').toUpperCase();

    return `HNW${suffix}`;
  }

  private devicePlatform(userAgent?: string | null): string {
    const value = (userAgent || '').toLowerCase();
    if (value.includes('android')) return 'Android';
    if (value.includes('iphone') || value.includes('ios')) return 'iOS';
    if (value.includes('windows')) return 'Windows';
    return 'Mobile';
  }

  private generateCustomerNo(): string {
    const suffix = randomBytes(5).toString('hex').toUpperCase();

    return `C${suffix}`;
  }

  private normalizeIndianPhone(value: string): string | null {
    const digits = value.replace(/\D/g, '');

    if (/^[6-9]\d{9}$/.test(digits)) {
      return digits;
    }

    if (/^91[6-9]\d{9}$/.test(digits)) {
      return digits.slice(2);
    }

    return null;
  }

  private phoneEmail(phone: string): string {
    return `91${phone}@phone.hnw.local`;
  }

  private defaultCustomerName(phone: string): string {
    return `Client ${phone.slice(-4)}`;
  }

  async currentUser(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        fullName: true,
        phone: true,
        role: true,
        status: true,
        businessProfile: { select: { employeeNo: true, department: true, isActive: true } },
      },
    });
    if (!user || user.status !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('User account is not active');
    }
    if (user.role === UserRole.BUSINESS && !user.businessProfile?.isActive) {
      throw new UnauthorizedException('Business account is not active');
    }
    return user;
  }
}
