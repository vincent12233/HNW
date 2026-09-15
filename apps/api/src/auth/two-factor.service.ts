import {
  BadRequestException,
  HttpException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  hkdfSync,
  randomBytes,
} from 'crypto';
import * as bcrypt from 'bcrypt';
import * as OTPAuth from 'otpauth';
import { Prisma, type TwoFactorCredential } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type AttemptFailure = { error: string; locked?: boolean };

type TotpProof = {
  lastStep?: number;
  recoveryHashes?: string[];
};

@Injectable()
export class TwoFactorService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  private key() {
    const dedicated = this.config
      .get<string>('TWO_FACTOR_ENCRYPTION_KEY')
      ?.trim();
    if (process.env.NODE_ENV === 'production') {
      if (
        !dedicated ||
        dedicated.length < 32 ||
        /replace|change-me|development/i.test(dedicated) ||
        dedicated === this.config.get<string>('JWT_SECRET')
      ) {
        throw new Error(
          'TWO_FACTOR_ENCRYPTION_KEY must be a unique random value of at least 32 characters',
        );
      }
      return Buffer.from(
        hkdfSync('sha256', dedicated, 'finvest', 'totp-encryption-v1', 32),
      );
    }
    const material = dedicated || this.config.getOrThrow<string>('JWT_SECRET');
    return Buffer.from(
      hkdfSync('sha256', material, 'finvest', 'totp-encryption-v1', 32),
    );
  }
  private encrypt(secret: string) {
    const iv = randomBytes(12),
      cipher = createCipheriv('aes-256-gcm', this.key(), iv);
    const ciphertext = Buffer.concat([
      cipher.update(secret, 'utf8'),
      cipher.final(),
    ]);
    return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]).toString(
      'base64',
    );
  }
  private decrypt(secret: string) {
    const bytes = Buffer.from(secret, 'base64');
    const cipher = createDecipheriv(
      'aes-256-gcm',
      this.key(),
      bytes.subarray(0, 12),
    );
    cipher.setAuthTag(bytes.subarray(12, 28));
    return Buffer.concat([
      cipher.update(bytes.subarray(28)),
      cipher.final(),
    ]).toString('utf8');
  }
  private otp(secret: string, label = 'Account') {
    return new OTPAuth.TOTP({
      issuer: 'Finvest',
      label,
      algorithm: 'SHA1',
      digits: 6,
      period: 30,
      secret: OTPAuth.Secret.fromBase32(secret),
    });
  }
  private hash(code: string) {
    return createHash('sha256').update(code).digest('hex');
  }

  async status(userId: string) {
    const row = await this.prisma.twoFactorCredential.findUnique({
      where: { userId },
    });
    return {
      enabled: row?.enabled ?? false,
      recoveryCodesRemaining: row?.recoveryHashes.length ?? 0,
    };
  }

  private isFailure(value: object): value is AttemptFailure {
    return (
      'error' in value &&
      typeof (value as AttemptFailure).error === 'string' &&
      Boolean((value as AttemptFailure).error)
    );
  }

  // Lock the credential row so retries, recovery codes and TOTP replays are atomic.
  private async attempt<T extends object>(
    userId: string,
    action: (
      tx: Prisma.TransactionClient,
      row: TwoFactorCredential,
    ) => Promise<T | AttemptFailure>,
  ): Promise<T> {
    await this.prisma.twoFactorCredential.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
    const result = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "userId" FROM "two_factor_credentials" WHERE "userId" = ${userId} FOR UPDATE`;
      const row = await tx.twoFactorCredential.findUniqueOrThrow({
        where: { userId },
      });
      if (row.lockedUntil && row.lockedUntil.getTime() > Date.now())
        return {
          error: 'Too many attempts. Try again in 15 minutes.',
          locked: true,
        } satisfies AttemptFailure;
      const value = await action(tx, row);
      if (this.isFailure(value)) {
        const attempts = row.lockedUntil ? 1 : row.attempts + 1;
        await tx.twoFactorCredential.update({
          where: { userId },
          data: {
            attempts,
            lockedUntil: attempts >= 5 ? new Date(Date.now() + 900000) : null,
          },
        });
      } else {
        await tx.twoFactorCredential.update({
          where: { userId },
          data: { attempts: 0, lockedUntil: null },
        });
      }
      return value;
    });
    if (this.isFailure(result))
      throw new HttpException(result.error, result.locked ? 429 : 400);
    return result;
  }

  async setup(userId: string, password: unknown) {
    return this.attempt(userId, async (tx, row) => {
      if (row.enabled)
        throw new BadRequestException(
          'Two-factor authentication is already enabled',
        );
      const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });
      if (
        typeof password !== 'string' ||
        Buffer.byteLength(password) > 72 ||
        !(await bcrypt.compare(password, user.passwordHash))
      )
        return { error: 'Current password is incorrect' };
      const secret = new OTPAuth.Secret({ size: 20 }).base32;
      const expiresAt = new Date(Date.now() + 600000);
      await tx.twoFactorCredential.update({
        where: { userId },
        data: {
          pendingSecret: this.encrypt(secret),
          pendingExpiresAt: expiresAt,
        },
      });
      return {
        secret,
        uri: this.otp(secret, user.phone || user.id).toString(),
        expiresAt,
      };
    });
  }

  private proof(
    row: TwoFactorCredential,
    code: unknown,
    pending = false,
  ): TotpProof | null {
    if (typeof code !== 'string' || code.length > 64) return null;
    const normalized = code.trim().toLowerCase();
    if (!pending && row.recoveryHashes.includes(this.hash(normalized)))
      return {
        recoveryHashes: row.recoveryHashes.filter(
          (hash) => hash !== this.hash(normalized),
        ),
      };
    const encrypted = pending ? row.pendingSecret : row.secret;
    if (!encrypted || !/^\d{6}$/.test(normalized)) return null;
    const timestamp = Date.now();
    const delta = this.otp(this.decrypt(encrypted)).validate({
      token: normalized,
      window: 1,
      timestamp,
    });
    const step = Math.floor(timestamp / 30000) + (delta ?? 0);
    return delta !== null && (pending || step > row.lastStep)
      ? { lastStep: step }
      : null;
  }

  async confirm(userId: string, code: unknown) {
    return this.attempt(userId, async (tx, row) => {
      if (
        row.enabled ||
        !row.pendingExpiresAt ||
        row.pendingExpiresAt.getTime() <= Date.now()
      )
        throw new BadRequestException('Start authenticator setup again');
      const proof = this.proof(row, code, true);
      if (!proof) return { error: 'Invalid verification code' };
      const recoveryCodes = Array.from({ length: 8 }, () =>
        randomBytes(16).toString('hex'),
      );
      await tx.twoFactorCredential.update({
        where: { userId },
        data: {
          ...proof,
          enabled: true,
          secret: row.pendingSecret,
          pendingSecret: null,
          pendingExpiresAt: null,
          recoveryHashes: recoveryCodes.map((code) => this.hash(code)),
        },
      });
      await tx.user.update({
        where: { id: userId },
        data: { authVersion: { increment: 1 } },
      });
      return { enabled: true as const, recoveryCodes };
    });
  }

  async disable(userId: string, password: unknown, code: unknown) {
    return this.attempt(userId, async (tx, row) => {
      const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });
      if (!row.enabled)
        throw new BadRequestException(
          'Two-factor authentication is not enabled',
        );
      if (
        typeof password !== 'string' ||
        Buffer.byteLength(password) > 72 ||
        !(await bcrypt.compare(password, user.passwordHash)) ||
        !this.proof(row, code)
      )
        return { error: 'Invalid password or verification code' };
      await tx.twoFactorCredential.update({
        where: { userId },
        data: {
          enabled: false,
          secret: null,
          pendingSecret: null,
          pendingExpiresAt: null,
          recoveryHashes: [],
          lastStep: -1,
        },
      });
      await tx.user.update({
        where: { id: userId },
        data: { authVersion: { increment: 1 } },
      });
      return { enabled: false as const };
    });
  }

  async verifyLogin(userId: string, code?: string) {
    if (!(await this.status(userId)).enabled) return;
    if (!code)
      throw new UnauthorizedException({
        message: 'Enter your authenticator code or recovery code',
        twoFactorRequired: true,
      });
    await this.attempt(userId, async (tx, row) => {
      if (!row.enabled)
        throw new UnauthorizedException(
          'Account security changed. Sign in again.',
        );
      const proof = this.proof(row, code);
      if (!proof) return { error: 'Invalid or already used verification code' };
      await tx.twoFactorCredential.update({ where: { userId }, data: proof });
      return { verified: true as const };
    });
  }
}
