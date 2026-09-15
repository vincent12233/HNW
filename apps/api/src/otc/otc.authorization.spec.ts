import { UnauthorizedException } from '@nestjs/common';
import { OtcService } from './otc.service';

describe('OtcService review authorization', () => {
  it('prevents a business operator from rejecting another operator customer order', async () => {
    const tx = {
      otcOrder: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'otc-1',
          status: 'PENDING',
          account: {
            userId: 'client-1',
            user: { assignedBusinessId: 'business-owner' },
          },
          instrument: { symbol: 'LMW' },
        }),
        updateMany: jest.fn(),
      },
      user: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ id: 'business-other', role: 'BUSINESS' }),
      },
      notification: { create: jest.fn() },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    const service = new OtcService(prisma as any);

    await expect(
      service.reject('business-other', 'otc-1', 'Rejected'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(tx.otcOrder.updateMany).not.toHaveBeenCalled();
    expect(tx.notification.create).not.toHaveBeenCalled();
  });
});
