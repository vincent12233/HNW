import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server } from 'socket.io';

@WebSocketGateway({ namespace: '/support', cors: { origin: '*' } })
export class SupportGateway {
  @WebSocketServer() server!: Server;

  conversationUpdated(conversationId: string) {
    this.server.emit('support-update', { conversationId, at: new Date() });
  }
}
