import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';

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

    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
      phone: user.phone,
      role: user.role,
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

  private generateAccountNumber(): string {
    const suffix = randomBytes(5).toString('hex').toUpperCase();

    return `HNW${suffix}`;
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
}
