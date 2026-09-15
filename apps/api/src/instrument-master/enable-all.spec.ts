import { InstrumentMasterService } from './instrument-master.service';
import { InstrumentMasterController } from './instrument-master.controller';

describe('Enable all equity instruments', () => {
  it('is restricted to the super administrator', () => {
    expect(
      Reflect.getMetadata(
        'roles',
        InstrumentMasterController.prototype.enableAll,
      ),
    ).toEqual(['ADMIN']);
  });
  it('updates all disabled NSE and BSE equities and audits the count atomically', async () => {
    const tx = {
      instrument: { updateMany: jest.fn().mockResolvedValue({ count: 2400 }) },
      auditLog: { create: jest.fn() },
    };
    const service = new InstrumentMasterService(
      { $transaction: (fn: any) => fn(tx) } as any,
      { get: () => undefined } as any,
    );
    await expect(service.enableAll('admin')).resolves.toEqual({
      updated: 2400,
    });
    expect(tx.instrument.updateMany).toHaveBeenCalledWith({
      where: {
        exchange: { in: ['NSE', 'BSE'] },
        type: 'EQUITY',
        isActive: false,
      },
      data: { isActive: true },
    });
    expect(tx.auditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          actorId: 'admin',
          metadata: {
            exchanges: ['NSE', 'BSE'],
            type: 'EQUITY',
            updated: 2400,
          },
        }),
      }),
    );
  });
});
