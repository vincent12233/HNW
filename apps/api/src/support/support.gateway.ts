import {
  OnGatewayInit,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';

@WebSocketGateway({
  namespace: '/support',
  cors: {
    origin: [
      ...(process.env.NODE_ENV === 'production'
        ? []
        : ['http://localhost:3001', 'http://localhost:3002']),
      ...(process.env.CORS_ORIGINS ?? '')
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean),
    ],
  },
})
export class SupportGateway implements OnGatewayInit {
  @WebSocketServer() server!: Server;
  private readonly connections = new Map<string, number>();
  private readonly maxConnectionsPerUser = Math.max(
    1,
    Number(process.env.WS_MAX_CONNECTIONS_PER_USER || 5),
  );

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  afterInit(server: Server) {
    server.use((socket, next) => void this.authenticate(socket, next));
  }

  private async authenticate(socket: Socket, next: (error?: Error) => void) {
    try {
      const token = String(socket.handshake.auth?.token || '').replace(
        /^Bearer\s+/i,
        '',
      );
      const payload = await this.jwt.verifyAsync<{
        sub: string;
        version?: number;
        purpose?: string;
      }>(token);
      if (!payload.sub || payload.purpose) throw new Error('Unauthorized');
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
        select: { status: true, authVersion: true },
      });
      if (
        !user ||
        user.status !== 'ACTIVE' ||
        payload.version !== user.authVersion
      )
        throw new Error('Unauthorized');
      const count = this.connections.get(payload.sub) ?? 0;
      if (count >= this.maxConnectionsPerUser)
        throw new Error('Connection limit exceeded');
      this.connections.set(payload.sub, count + 1);
      socket.data.userId = payload.sub;
      await socket.join(`user:${payload.sub}`);
      socket.once('disconnect', () => this.releaseConnection(payload.sub));
      next();
    } catch {
      next(new Error('Unauthorized websocket connection'));
    }
  }

  private releaseConnection(userId: string) {
    const count = this.connections.get(userId) ?? 0;
    if (count <= 1) this.connections.delete(userId);
    else this.connections.set(userId, count - 1);
  }

  async conversationUpdated(conversationId: string) {
    try {
      const conversation = await this.prisma.supportConversation.findUnique({
        where: { id: conversationId },
        select: { clientId: true, assignedToId: true },
      });
      if (!conversation) return;

      const payload = { conversationId, at: new Date() };
      const rooms = new Set<string>([`user:${conversation.clientId}`]);
      if (conversation.assignedToId) {
        rooms.add(`user:${conversation.assignedToId}`);
      }
      for (const room of rooms) {
        this.server.to(room).emit('support-update', payload);
      }
    } catch {
      // Best-effort fanout; callers intentionally do not await.
    }
  }
}
