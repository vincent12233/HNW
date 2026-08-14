import { NotFoundException } from '@nestjs/common';
import { UserStatus } from '../generated/prisma/enums';
import { BusinessService } from './business.service';

describe('BusinessService customer isolation', () => {
  it('cannot update a customer that is not assigned to the current business operator', async () => {
    const prisma = {
      user: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        findUniqueOrThrow: jest.fn(),
      },
    };
    const audit = { createLog: jest.fn() };
    const service = new BusinessService(prisma as any, {} as any, audit as any);

    await expect(service.updateMyCustomerStatus('business-1', 'customer-2', UserStatus.SUSPENDED))
      .rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.user.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ assignedBusinessId: 'business-1', id: 'customer-2' }),
    }));
    expect(prisma.user.findUniqueOrThrow).not.toHaveBeenCalled();
    expect(audit.createLog).not.toHaveBeenCalled();
  });
});
