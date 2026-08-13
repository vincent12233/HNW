import { OnGatewayInit, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';

@WebSocketGateway({
  namespace: '/support',
  cors: {
    origin: [
      'http://localhost:3001',
      'http://localhost:3002',
      ...(process.env.CORS_ORIGINS ?? '').split(',').map((value) => value.trim()).filter(Boolean),
    ],
  },
})
export class SupportGateway implements OnGatewayInit {
  @WebSocketServer() server!: Server;

  constructor(private readonly jwt: JwtService, private readonly prisma: PrismaService) {}

  afterInit(server: Server) {
    server.use((socket, next) => void this.authenticate(socket, next));
  }

  private async authenticate(socket: Socket, next: (error?: Error) => void) {
    try {
      const token = String(socket.handshake.auth?.token || '').replace(/^Bearer\s+/i, '');
      const payload = await this.jwt.verifyAsync<{ sub: string; version?: number }>(token);
      const user = await this.prisma.user.findUnique({ where: { id: payload.sub }, select: { status: true, authVersion: true } });
      if (!user || user.status !== 'ACTIVE' || payload.version !== user.authVersion) throw new Error('Unauthorized');
      socket.data.userId = payload.sub;
      next();
    } catch { next(new Error('Unauthorized websocket connection')); }
  }

  conversationUpdated(conversationId: string) {
    this.server.emit('support-update', { conversationId, at: new Date() });
  }
}
