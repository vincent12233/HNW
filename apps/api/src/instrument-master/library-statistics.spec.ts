import { InstrumentMasterService } from './instrument-master.service';

describe('Independent exchange libraries', () => {
  it('counts the entire exchange even when the table is paginated and filtered', async () => {
    const instrument = {
      count: jest
        .fn()
        .mockResolvedValueOnce(7)
        .mockResolvedValueOnce(2306)
        .mockResolvedValueOnce(2306)
        .mockResolvedValueOnce(2000),
      findMany: jest.fn().mockResolvedValue([]),
    };
    const service = new InstrumentMasterService(
      {
        instrument,
        $transaction: (queries: any[]) => Promise.all(queries),
      } as any,
      { get: () => undefined } as any,
    );
    const result = await service.list({
      exchange: 'NSE',
      search: 'ABC',
      active: true,
      page: 2,
      pageSize: 50,
    });
    expect(result.statistics).toEqual({
      total: 2306,
      enabled: 2306,
      quoted: 2000,
    });
    expect(result.total).toBe(7);
    expect(instrument.count.mock.calls[1][0]).toEqual({
      where: { exchange: { in: ['NSE'] }, type: 'EQUITY' },
    });
    expect(instrument.findMany.mock.calls[0][0]).toMatchObject({
      skip: 50,
      take: 50,
    });
  });
  it('enables only the selected exchange', async () => {
    const tx = {
      instrument: { updateMany: jest.fn().mockResolvedValue({ count: 4 }) },
      auditLog: { create: jest.fn() },
    };
    const service = new InstrumentMasterService(
      { $transaction: (fn: any) => fn(tx) } as any,
      { get: () => undefined } as any,
    );
    await service.enableAll('admin', 'BSE');
    expect(tx.instrument.updateMany.mock.calls[0][0].where.exchange).toEqual({
      in: ['BSE'],
    });
  });
  it('runs NSE automatically and skips BSE until configured', async () => {
    const service = new InstrumentMasterService(
      {} as any,
      { get: () => undefined } as any,
    );
    const nse = jest
      .spyOn(service, 'syncNseEquities')
      .mockResolvedValue({ created: 1, updated: 2 } as any);
    const bse = jest.spyOn(service, 'syncBseEquities');
    await service.scheduledNseSync();
    await service.scheduledBseSync();
    expect(nse).toHaveBeenCalledTimes(1);
    expect(bse).not.toHaveBeenCalled();
    const configured = new InstrumentMasterService(
      {} as any,
      { get: () => 'https://example.test/bse.csv' } as any,
    );
    const sync = jest
      .spyOn(configured, 'syncBseEquities')
      .mockResolvedValue({ created: 1 } as any);
    await configured.scheduledBseSync();
    expect(sync).toHaveBeenCalledTimes(1);
  });
});
