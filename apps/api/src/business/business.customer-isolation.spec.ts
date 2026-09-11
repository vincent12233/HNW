import { NotFoundException } from '@nestjs/common';
import { UserStatus } from '../generated/prisma/enums';
import { BusinessService } from './business.service';

describe('BusinessService customer isolation', () => {
  it('limits membership writes to owned customers and audits the change', async () => {
    const tx = { user: { findFirst: jest.fn().mockResolvedValue({ clientTier: 'STANDARD' }),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }) }, auditLog: { create: jest.fn() } };
    const service = new BusinessService({ $transaction: (fn: any) => fn(tx) } as any, {} as any, {} as any);
    await expect(service.updateCustomerTier('business-1', 'client-1', 'GOLD')).resolves.toEqual({ id: 'client-1', clientTier: 'GOLD' });
    expect(tx.user.updateMany).toHaveBeenCalledWith({ where: { id: 'client-1', role: 'CLIENT', assignedBusinessId: 'business-1' }, data: { clientTier: 'GOLD' } });
    expect(tx.auditLog.create).toHaveBeenCalledTimes(1);
    tx.user.findFirst.mockResolvedValue(null);
    await expect(service.updateCustomerTier('business-1', 'other-client', 'GOLD')).rejects.toThrow();
    await expect(service.updateCustomerTier('business-1', 'client-1', 'VIP')).rejects.toThrow();
    expect(tx.user.updateMany).toHaveBeenCalledTimes(1);
  });
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
