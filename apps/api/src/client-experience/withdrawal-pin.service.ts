import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class WithdrawalPinService {
  constructor(private readonly prisma: PrismaService) {}

  async status(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { withdrawalPinHash: true } });
    return { configured: Boolean(user?.withdrawalPinHash) };
  }

  async verify(userId: string, pin: unknown) {
    return this.check(userId, pin);
  }

  async change(userId: string, body: { currentPassword?: unknown; currentPin?: unknown; newPin?: unknown }) {
    if (typeof body.newPin !== 'string' || !/^\d{6}$/.test(body.newPin)) {
      throw new BadRequestException('Withdrawal PIN must contain 6 digits');
    }
    await this.check(userId, body.currentPin, body.currentPassword, body.newPin);
    return { changed: true };
  }

  private async check(userId: string, pin: unknown, password?: unknown, newPin?: string) {
    // Commit failed-attempt counters before raising an HTTP error, including across API replicas.
    const result = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${userId} FOR UPDATE`;
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) return 'Account not found';
      if (user.withdrawalPinLockedUntil && user.withdrawalPinLockedUntil > new Date()) {
        return 'Too many attempts. Try again in 15 minutes';
      }
      if (!newPin && !user.withdrawalPinHash) return 'Set your withdrawal PIN in Profile first';
      const passwordValid = !newPin || (typeof password === 'string' && password.length <= 72 && await bcrypt.compare(password, user.passwordHash));
      const pinValid = !user.withdrawalPinHash || (typeof pin === 'string' && /^\d{6}$/.test(pin) && await bcrypt.compare(pin, user.withdrawalPinHash));
      if (!passwordValid || !pinValid) {
        const attempts = user.withdrawalPinLockedUntil ? 1 : user.withdrawalPinAttempts + 1;
        await tx.user.update({ where: { id: userId }, data: {
          withdrawalPinAttempts: attempts,
          withdrawalPinLockedUntil: attempts >= 5 ? new Date(Date.now() + 15 * 60_000) : null,
        } });
        return 'Incorrect password or withdrawal PIN';
      }
      await tx.user.update({ where: { id: userId }, data: {
        withdrawalPinAttempts: 0, withdrawalPinLockedUntil: null,
        ...(newPin ? { withdrawalPinHash: await bcrypt.hash(newPin, 12) } : {}),
      } });
      return null;
    }, { timeout: 15_000 });
    if (result) throw new ForbiddenException(result);
  }
}
