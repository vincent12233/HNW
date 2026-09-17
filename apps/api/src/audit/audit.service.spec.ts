import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from './audit.service';

describe('AuditService write client selection', () => {
  const entry = {
    actorId: 'finance',
    action: 'DEPOSIT_APPROVED',
    resource: 'deposit',
    resourceId: 'deposit-1',
    metadata: { creditedAmount: '200.00' },
  };

  it('preserves standalone writes when no transaction is supplied', async () => {
    const create = jest.fn().mockResolvedValue({ id: 'audit-1' });
    const service = new AuditService({
      auditLog: { create },
    } as unknown as PrismaService);

    await expect(service.createLog(entry)).resolves.toEqual({
      id: 'audit-1',
    });
    expect(create).toHaveBeenCalledWith({
      data: expect.objectContaining(entry),
    });
  });

  it('uses the supplied transaction and propagates its failure without fallback', async () => {
    const failure = new Error('audit insert failed');
    const standaloneCreate = jest.fn();
    const transactionCreate = jest.fn().mockRejectedValue(failure);
    const service = new AuditService({
      auditLog: { create: standaloneCreate },
    } as unknown as PrismaService);
    const tx = {
      auditLog: { create: transactionCreate },
    } as unknown as Prisma.TransactionClient;

    await expect(service.createLog(entry, tx)).rejects.toBe(failure);
    expect(transactionCreate).toHaveBeenCalledTimes(1);
    expect(transactionCreate).toHaveBeenCalledWith({
      data: expect.objectContaining(entry),
    });
    expect(standaloneCreate).not.toHaveBeenCalled();
  });
});
