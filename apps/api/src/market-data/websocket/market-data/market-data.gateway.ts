import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';

import { Server } from 'socket.io';

import { Logger } from '@nestjs/common';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class MarketDataGateway {
  private readonly logger = new Logger(MarketDataGateway.name);

  @WebSocketServer()
  server: Server;

  emitQuoteUpdate(data: any) {
    if (!this.server) {
      return;
    }

    this.server.emit('market-update', data);

    this.logger.log(`Broadcast ${data.symbol} ${data.price}`);
  }
}
