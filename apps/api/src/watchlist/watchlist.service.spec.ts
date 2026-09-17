import { NotFoundException } from '@nestjs/common';
import { ordinaryMarketCategoryWhere } from '../common/instrument-category';
import { WatchlistService } from './watchlist.service';

describe('WatchlistService ordinary isolation', () => {
  it('refuses to add a special-product instrument to the ordinary watchlist', async () => {
    const prisma = {
      instrument: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
      $executeRaw: jest.fn(),
    };
    const service = new WatchlistService(prisma as never);

    await expect(
      service.add('user-1', 'IPOCO', 'NSE' as never),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.instrument.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          AND: [ordinaryMarketCategoryWhere()],
        }),
      }),
    );
    expect(prisma.$executeRaw).not.toHaveBeenCalled();
  });
});
