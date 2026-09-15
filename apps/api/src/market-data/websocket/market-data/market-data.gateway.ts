import {
  OnGatewayInit,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';

import { Server, Socket } from 'socket.io';

import { Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service';

@WebSocketGateway({
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
export class MarketDataGateway
  implements OnGatewayInit, OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(MarketDataGateway.name);
  private heartbeatTimer?: NodeJS.Timeout;
  private readonly connections = new Map<string, number>();
  private readonly maxConnectionsPerUser = Math.max(
    1,
    Number(process.env.WS_MAX_CONNECTIONS_PER_USER || 5),
  );

  @WebSocketServer()
  server: Server;

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

  onModuleInit() {
    this.heartbeatTimer = setInterval(() => {
      this.server?.emit('market-heartbeat', {
        serverTime: new Date().toISOString(),
      });
    }, 25000);
  }

  onModuleDestroy() {
    if (this.heartbeatTimer) clearInterval(this.heartbeatTimer);
  }

  emitQuoteUpdate(data: any) {
    if (!this.server) {
      return;
    }

    this.server.emit('market-update', data);

    this.logger.log(`Broadcast ${data.symbol} ${data.price}`);
  }
}
