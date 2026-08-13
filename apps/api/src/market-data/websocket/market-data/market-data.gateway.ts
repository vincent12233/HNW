import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';

import { Server } from 'socket.io';

import { Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class MarketDataGateway implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MarketDataGateway.name);
  private heartbeatTimer?: NodeJS.Timeout;

  @WebSocketServer()
  server: Server;

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
