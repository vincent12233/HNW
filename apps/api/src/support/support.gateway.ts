import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server } from 'socket.io';

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
export class SupportGateway {
  @WebSocketServer() server!: Server;

  conversationUpdated(conversationId: string) {
    this.server.emit('support-update', { conversationId, at: new Date() });
  }
}
