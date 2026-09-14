import { JwtService } from '@nestjs/jwt';
import { Socket } from 'socket.io';

type PrismaUserLookup = {
  user: {
    findUnique: (args: {
      where: { id: string };
      select: { status: true; authVersion: true };
    }) => Promise<{ status: string; authVersion: number } | null>;
  };
};

type ConnectionTracker = {
  connections: Map<string, number>;
  maxConnectionsPerUser: number;
};

/**
 * Shared Socket.IO auth: reject purpose-scoped JWTs (biometric/KYC) the same
 * way HTTP JwtStrategy does, and enforce per-user connection caps.
 */
export async function authenticateSocket(
  socket: Socket,
  next: (error?: Error) => void,
  deps: {
    jwt: JwtService;
    prisma: PrismaUserLookup;
    tracker: ConnectionTracker;
  },
) {
  try {
    const token = String(socket.handshake.auth?.token || '').replace(
      /^Bearer\s+/i,
      '',
    );
    const payload = await deps.jwt.verifyAsync<{
      sub: string;
      version?: number;
      purpose?: string;
    }>(token);
    if (!payload.sub || payload.purpose) {
      throw new Error('Unauthorized');
    }
    const user = await deps.prisma.user.findUnique({
      where: { id: payload.sub },
      select: { status: true, authVersion: true },
    });
    if (
      !user ||
      user.status !== 'ACTIVE' ||
      payload.version !== user.authVersion
    ) {
      throw new Error('Unauthorized');
    }
    const count = deps.tracker.connections.get(payload.sub) ?? 0;
    if (count >= deps.tracker.maxConnectionsPerUser) {
      throw new Error('Connection limit exceeded');
    }
    deps.tracker.connections.set(payload.sub, count + 1);
    socket.data.userId = payload.sub;
    socket.once('disconnect', () => {
      const current = deps.tracker.connections.get(payload.sub) ?? 0;
      if (current <= 1) deps.tracker.connections.delete(payload.sub);
      else deps.tracker.connections.set(payload.sub, current - 1);
    });
    next();
  } catch {
    next(new Error('Unauthorized websocket connection'));
  }
}
