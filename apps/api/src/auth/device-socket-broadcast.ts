import { Server } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';

/** Existing sockets must not keep receiving protected data after a device is revoked. */
export async function emitToDeviceSessions(
  prisma: PrismaService,
  server: Server,
  event: string,
  payload: unknown,
  rooms?: string[],
) {
  const sockets = await (rooms ? server.in(rooms) : server).fetchSockets();
  const ids = sockets
    .map((socket) => (socket.data as { sessionId?: string }).sessionId)
    .filter((id): id is string => !!id);
  if (!ids.length) return;
  const active = await prisma.userDevice.findMany({
    where: {
      id: { in: ids },
      sessionBound: true,
      revokedAt: null,
      user: { status: 'ACTIVE', deletedAt: null },
    },
    select: { id: true, userId: true },
  });
  const allowed = new Map(active.map((device) => [device.id, device.userId]));
  for (const socket of sockets) {
    const data = socket.data as { sessionId?: string; userId?: string };
    if (
      data.sessionId &&
      data.userId &&
      allowed.get(data.sessionId) === data.userId
    )
      socket.emit(event, payload);
    else socket.disconnect(true);
  }
}
