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
import { normalizePhone, internationalPhone } from './phone-number';
import { TwoFactorService } from './two-factor.service';
import { fixedInviteCode } from '../common/fixed-invite';
@Injectable()
export class AuthService {
  // Sessions stay valid until explicit logout (or authVersion revocation).
  private static readonly CLIENT_TOKEN_SECONDS = 365 * 24 * 60 * 60;
  private static readonly STAFF_TOKEN_SECONDS = 365 * 24 * 60 * 60;
  private static readonly ACCESS_TOKEN_TTL = '365d';

  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly twoFactor: TwoFactorService,
  ) {}

  private isStaffRole(role: UserRole) {
    return role !== UserRole.CLIENT;
  }

  private accessTokenExpiresIn(role: UserRole) {
    return this.isStaffRole(role)
      ? AuthService.STAFF_TOKEN_SECONDS
      : AuthService.CLIENT_TOKEN_SECONDS;
  }

  private async issueAccessToken(user: {
    id: string;
    phone: string | null;
    role: UserRole;
    authVersion: number;
  }) {
    return this.jwtService.signAsync(
      {
        sub: user.id,
        phone: user.phone,
        role: user.role,
        version: user.authVersion,
      },
      { expiresIn: AuthService.ACCESS_TOKEN_TTL },
    );
  }

  async register(dto: RegisterDto) {
    const phone = normalizePhone(dto.phone);

    if (!phone) {
      throw new BadRequestException('Invalid mobile number');
    }

    const email = this.phoneEmail(phone);
    const inviteCodeValue = dto.inviteCode.trim().toUpperCase();
    const fixedCode = fixedInviteCode();
    const reusableInvite = inviteCodeValue === fixedCode;

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

      if (!reusableInvite && inviteCode.status === InviteCodeStatus.USED) {
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

      if (!reusableInvite) {
        const claimedInviteCode = await tx.inviteCode.updateMany({
          where: { id: inviteCode.id, status: InviteCodeStatus.UNUSED },
          data: { status: InviteCodeStatus.USED, usedAt: new Date() },
        });
        if (claimedInviteCode.count !== 1) {
          throw new BadRequestException('Invite code has already been used');
        }
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
          usedInviteCodeId: inviteCode.id,
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

      return user;
    });

    return {
      message: 'Registration successful',
      kycToken: await this.jwtService.signAsync(
        { sub: result.id, role: result.role, version: result.authVersion, purpose: 'KYC_ONBOARDING' },
        { expiresIn: '30m' },
      ),
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
    const phone = dto.phone ? normalizePhone(dto.phone) : null;
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

    const lockoutWindowMs = 15 * 60 * 1000;
    const failedAttempts = await this.prisma.loginAudit.count({
      where: {
        userId: user.id,
        success: false,
        createdAt: { gte: new Date(Date.now() - lockoutWindowMs) },
      },
    });
    if (failedAttempts >= 5) {
      throw new HttpException(
        'Too many failed login attempts. Try again in 15 minutes.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
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
        const approved = await this.prisma.$queryRaw<{ id: string }[]>`SELECT "id" FROM "kyc_submissions" WHERE "userId" = ${user.id} AND "status" = 'APPROVED' LIMIT 1`;
        if (!approved.length) {
          throw new UnauthorizedException({ message: 'KYC verification required', kycToken: await this.jwtService.signAsync(
            { sub: user.id, role: user.role, version: user.authVersion, purpose: 'KYC_ONBOARDING' }, { expiresIn: '30m' },
          ) });
        }
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

    await this.twoFactor.verifyLogin(user.id, dto.verificationCode);

    await this.prisma.loginAudit.create({
      data: { userId: user.id, ipAddress: context?.ipAddress || null, userAgent: context?.userAgent || null, success: true },
    });

    await this.prisma.userDevice.create({
      data: {
        userId: user.id,
        deviceName: (context?.userAgent || 'Mobile device').slice(0, 80),
        platform: this.devicePlatform(context?.userAgent),
        lastIp: context?.ipAddress || null,
      },
    });

    const accessToken = await this.issueAccessToken(user);

    return {
      message: 'Login successful',
      accessToken,
      tokenType: 'Bearer',
      expiresIn: this.accessTokenExpiresIn(user.role),
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
    throw new BadRequestException('Contact customer support to reset your password');
  }

  async confirmPasswordReset(phoneValue: string, code: string, newPassword: string) {
    throw new BadRequestException('Use the reset code in your customer support session');
  }

  async googleLogin(idToken: string) {
    const { subject } = await this.verifyGoogleToken(idToken);
    // Require an explicit prior linkGoogle binding — do not auto-claim by email.
    const user = await this.prisma.user.findFirst({
      where: { googleSubject: subject },
      include: { account: true },
    });
    if (!user || user.status !== UserStatus.ACTIVE) throw new UnauthorizedException('Google account is not linked to an active trading account');
    if ((await this.twoFactor.status(user.id)).enabled) throw new UnauthorizedException('Use password sign in with your authenticator code');
    const accessToken = await this.issueAccessToken(user);
    return {
      message: 'Login successful',
      accessToken,
      tokenType: 'Bearer',
      expiresIn: this.accessTokenExpiresIn(user.role),
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
    const issuer = String(response.data?.iss || '');
    const clientId = this.config.get<string>('GOOGLE_CLIENT_ID')?.trim();
    const emailVerified =
      response.data?.email_verified === true ||
      response.data?.email_verified === 'true';
    const allowedIssuers = new Set([
      'accounts.google.com',
      'https://accounts.google.com',
    ]);
    if (
      !subject ||
      !email ||
      !clientId ||
      audience !== clientId ||
      !emailVerified ||
      !allowedIssuers.has(issuer)
    ) {
      throw new UnauthorizedException('Google account could not be verified');
    }
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
    if ((await this.twoFactor.status(user.id)).enabled) throw new UnauthorizedException('Use password sign in with your authenticator code');
    const accessToken = await this.issueAccessToken(user);
    return {
      message: 'Login successful',
      accessToken,
      tokenType: 'Bearer',
      expiresIn: this.accessTokenExpiresIn(user.role),
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
    return `${internationalPhone(phone).slice(1)}@phone.hnw.local`;
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
