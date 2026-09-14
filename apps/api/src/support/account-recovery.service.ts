import { BadRequestException, HttpException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { createHash, randomBytes, randomUUID } from 'crypto';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { normalizePhone } from '../auth/phone-number';

type RecoverySession = {
  id: string; phone: string; status: string; expiresAt: Date;
  codeHash: string | null; codeExpiresAt: Date | null; codeUsedAt: Date | null;
  codeAttempts: number; issuedUserId: string | null;
};

@Injectable()
export class AccountRecoveryService {
  constructor(private readonly prisma: PrismaService) {}

  async open(phoneValue: string) {
    const phone = normalizePhone(phoneValue);
    if (!phone) throw new BadRequestException('Enter a valid mobile number');
    const recent = await this.prisma.$queryRaw<{ count: bigint }[]>`SELECT COUNT(*) AS count FROM account_recovery_sessions WHERE phone = ${phone} AND "createdAt" > CURRENT_TIMESTAMP - INTERVAL '1 hour'`;
    if (Number(recent[0]?.count) >= 5) throw new HttpException('Too many support requests. Try again later.', 429);
    const id = randomUUID(), token = randomBytes(32).toString('hex');
    const hash = createHash('sha256').update(token).digest('hex');
    await this.prisma.$executeRaw`INSERT INTO account_recovery_sessions (id, phone, "tokenHash", "expiresAt") VALUES (${id}::uuid, ${phone}, ${hash}, CURRENT_TIMESTAMP + INTERVAL '24 hours')`;
    return { id, token };
  }

  private async session(token: string): Promise<RecoverySession> {
    if (!/^[a-f0-9]{64}$/.test(token)) throw new UnauthorizedException('Support session expired. Please reconnect.');
    const hash = createHash('sha256').update(token).digest('hex');
    const rows = await this.prisma.$queryRaw<RecoverySession[]>`SELECT * FROM account_recovery_sessions WHERE "tokenHash" = ${hash} AND "expiresAt" > CURRENT_TIMESTAMP LIMIT 1`;
    if (!rows[0]) throw new UnauthorizedException('Support session expired. Please reconnect.');
    return rows[0];
  }

  async messages(token: string) {
    const session = await this.session(token);
    const messages = await this.prisma.$queryRaw`SELECT id, sender, content, "createdAt" FROM account_recovery_messages WHERE "sessionId" = ${session.id}::uuid ORDER BY "createdAt", id`;
    return { status: session.status, messages };
  }

  async send(token: string, content: string) {
    const session = await this.session(token);
    if (session.status !== 'OPEN') throw new BadRequestException('This support request is closed');
    return this.insertMessage(session.id, 'CLIENT', content);
  }

  async list() {
    return this.prisma.$queryRaw`SELECT id, phone, status, "createdAt", "updatedAt", "issuedById" FROM account_recovery_sessions WHERE "expiresAt" > CURRENT_TIMESTAMP ORDER BY "updatedAt" DESC LIMIT 200`;
  }
  async staffMessages(id: string) {
    this.validateId(id);
    return this.prisma.$queryRaw`SELECT id, sender, content, "createdAt" FROM account_recovery_messages WHERE "sessionId" = ${id}::uuid ORDER BY "createdAt", id`;
  }
  async staffSend(id: string, content: string) {
    this.validateId(id);
    const rows = await this.prisma.$queryRaw<{ id: string }[]>`SELECT id FROM account_recovery_sessions WHERE id = ${id}::uuid AND status = 'OPEN' AND "expiresAt" > CURRENT_TIMESTAMP`;
    if (!rows.length) throw new NotFoundException('Open support request not found');
    return this.insertMessage(id, 'SUPPORT', content);
  }
  private validateId(id: string) {
    if (typeof id !== 'string' || !/^[a-f0-9-]{36}$/i.test(id)) throw new BadRequestException('Invalid request ID');
  }
  private async insertMessage(id: string, sender: string, value: string) {
    const content = typeof value === 'string' ? value.trim() : '';
    if (!content || content.length > 2000) throw new BadRequestException('Message must contain 1 to 2000 characters');
    await this.prisma.$transaction(async tx => {
      await tx.$executeRaw`INSERT INTO account_recovery_messages (id, "sessionId", sender, content) VALUES (${randomUUID()}::uuid, ${id}::uuid, ${sender}, ${content})`;
      await tx.$executeRaw`UPDATE account_recovery_sessions SET "updatedAt" = CURRENT_TIMESTAMP WHERE id = ${id}::uuid`;
    });
    return { sent: true };
  }

  async issue(id: string, actorId: string, verified: boolean) {
    this.validateId(id);
    if (verified !== true) throw new BadRequestException('Confirm customer identity before issuing a reset code');
    const code = randomBytes(6).toString('hex').toUpperCase();
    const codeHash = await bcrypt.hash(code, 12);
    await this.prisma.$transaction(async tx => {
      const rows = await tx.$queryRaw<RecoverySession[]>`SELECT * FROM account_recovery_sessions WHERE id = ${id}::uuid AND status = 'OPEN' AND "expiresAt" > CURRENT_TIMESTAMP FOR UPDATE`;
      const session = rows[0];
      if (!session) throw new NotFoundException('Open support request not found');
      if (session.codeExpiresAt && session.codeExpiresAt.getTime() > Date.now()) throw new BadRequestException('A reset code has already been sent and is still valid');
      const user = await tx.user.findFirst({ where: { phone: session.phone, role: 'CLIENT', status: { not: 'DISABLED' } } });
      if (!user) throw new BadRequestException('No eligible customer account matches this phone');
      await tx.$executeRaw`UPDATE account_recovery_sessions SET "codeHash" = ${codeHash}, "codeExpiresAt" = CURRENT_TIMESTAMP + INTERVAL '10 minutes', "codeUsedAt" = NULL, "codeAttempts" = 0, "issuedById" = ${actorId}, "issuedUserId" = ${user.id}, "updatedAt" = CURRENT_TIMESTAMP WHERE id = ${id}::uuid`;
      const content = `A one-time password reset code was issued. It expires in 10 minutes and can only be used once. Ask support for the code shown on their screen — it is not stored in chat.`;
      await tx.$executeRaw`INSERT INTO account_recovery_messages (id, "sessionId", sender, content) VALUES (${randomUUID()}::uuid, ${id}::uuid, 'SUPPORT', ${content})`;
      await tx.auditLog.create({ data: { actorId, action: 'SUPPORT_PASSWORD_RESET_ISSUED', resource: 'account_recovery', resourceId: id, description: 'Support confirmed identity and issued a single-use reset code' } });
    });
    return { sent: true, code };
  }

  async reset(token: string, codeValue: string, newPassword: string) {
    const session = await this.session(token);
    const code = typeof codeValue === 'string' ? codeValue.trim().toUpperCase() : '';
    if (!/^[A-F0-9]{12}$/.test(code) || typeof newPassword !== 'string' || newPassword.length < 8 || Buffer.byteLength(newPassword) > 72) throw new BadRequestException('Enter the reset code and a password of 8 to 72 bytes');
    const passwordHash = await bcrypt.hash(newPassword, 12);
    const changed = await this.prisma.$transaction(async tx => {
      const [current] = await tx.$queryRaw<RecoverySession[]>`SELECT * FROM account_recovery_sessions WHERE id = ${session.id}::uuid FOR UPDATE`;
      if (!current || current.status !== 'OPEN' || !current.codeHash || !current.issuedUserId || current.codeUsedAt || !current.codeExpiresAt || current.codeExpiresAt.getTime() < Date.now() || current.codeAttempts >= 5) return false;
      if (!await bcrypt.compare(code, current.codeHash)) {
        await tx.$executeRaw`UPDATE account_recovery_sessions SET "codeAttempts" = "codeAttempts" + 1 WHERE id = ${session.id}::uuid`;
        return false;
      }
      const updated = await tx.user.updateMany({ where: { id: current.issuedUserId, phone: current.phone, role: 'CLIENT', status: { not: 'DISABLED' } }, data: { passwordHash, authVersion: { increment: 1 } } });
      if (updated.count !== 1) return false;
      await tx.$executeRaw`UPDATE account_recovery_sessions SET "codeUsedAt" = CURRENT_TIMESTAMP, status = 'CLOSED', "updatedAt" = CURRENT_TIMESTAMP WHERE phone = ${current.phone} AND status = 'OPEN'`;
      await tx.passwordResetCode.updateMany({ where: { userId: current.issuedUserId, usedAt: null }, data: { usedAt: new Date() } });
      await tx.notification.create({ data: { userId: current.issuedUserId, type: 'SECURITY', title: 'Password changed', body: 'Your password was reset with customer support.' } });
      await tx.auditLog.create({ data: { actorId: current.issuedUserId, action: 'SUPPORT_PASSWORD_RESET_COMPLETED', resource: 'account_recovery', resourceId: current.id } });
      return true;
    });
    if (!changed) throw new BadRequestException('Invalid or expired reset code');
    return { changed: true };
  }
}
