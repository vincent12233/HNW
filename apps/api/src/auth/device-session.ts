import { UnauthorizedException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';

/** Always reads the primary database: revocation is effective across instances without cache delay. */
export async function requireDeviceSession(
  db: Prisma.TransactionClient,
  userId: string,
  sessionId: string | undefined,
  lock = false,
) {
  if (!sessionId)
    throw new UnauthorizedException(
      'Sign in again to bind this device session',
    );
  if (lock)
    await db.$queryRaw`SELECT id FROM user_devices WHERE id = ${sessionId} AND "userId" = ${userId} FOR UPDATE`;
  const device = await db.userDevice.findFirst({
    where: { id: sessionId, userId, sessionBound: true, revokedAt: null },
  });
  if (!device)
    throw new UnauthorizedException('Device session has been revoked');
  return device;
}
