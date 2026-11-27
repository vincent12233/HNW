import { emitToDeviceSessions } from './device-socket-broadcast';

describe('Existing device sockets', () => {
  it('rechecks authoritative device state before fanout and disconnects revoked sockets', async () => {
    const first = {
      data: { sessionId: 'device-1', userId: 'user' },
      emit: jest.fn(),
      disconnect: jest.fn(),
    };
    const second = {
      data: { sessionId: 'device-2', userId: 'user' },
      emit: jest.fn(),
      disconnect: jest.fn(),
    };
    const prisma = {
      userDevice: {
        findMany: jest
          .fn()
          .mockResolvedValue([{ id: 'device-2', userId: 'user' }]),
      },
    };
    const server = {
      fetchSockets: jest.fn().mockResolvedValue([first, second]),
    };
    await emitToDeviceSessions(
      prisma as never,
      server as never,
      'support-update',
      { conversationId: 'conversation' },
    );
    expect(first.emit).not.toHaveBeenCalled();
    expect(first.disconnect).toHaveBeenCalledWith(true);
    expect(second.emit).toHaveBeenCalledWith('support-update', {
      conversationId: 'conversation',
    });
    expect(second.disconnect).not.toHaveBeenCalled();
  });
});
