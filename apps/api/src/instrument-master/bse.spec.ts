import axios from 'axios';
import { InstrumentMasterService } from './instrument-master.service';

describe('BSE equity management', () => {
  afterEach(() => jest.restoreAllMocks());
  it('requires a configured real source', async () => {
    const service = new InstrumentMasterService(
      {} as any,
      { get: () => undefined } as any,
    );
    await expect(service.syncBseEquities()).rejects.toThrow('not configured');
  });
  it('imports BSE independently and preserves existing activation', async () => {
    jest
      .spyOn(axios, 'get')
      .mockResolvedValue({
        data: 'SECURITY CODE,SECURITY NAME,ISIN\n500325,"Company, Limited",INE002A01018\n500112,Other,INE062A01020',
      });
    const instrument = {
      findUnique: jest
        .fn()
        .mockResolvedValueOnce({ id: 'bse-existing', category: 'EQUITY' })
        .mockResolvedValueOnce(null),
      update: jest.fn(),
      create: jest.fn(),
    };
    const service = new InstrumentMasterService(
      { instrument } as any,
      { get: () => 'https://example.test/equities.csv' } as any,
    );
    await expect(service.syncBseEquities()).resolves.toMatchObject({
      created: 1,
      updated: 1,
    });
    expect(instrument.findUnique).toHaveBeenCalledWith({
      where: { exchange_symbol: { exchange: 'BSE', symbol: '500325' } },
      select: { id: true, category: true },
    });
    expect(instrument.update.mock.calls[0][0].data).not.toHaveProperty(
      'isActive',
    );
    expect(instrument.update.mock.calls[0][0].data.category).toBe('EQUITY');
    expect(instrument.create.mock.calls[0][0].data).toMatchObject({
      exchange: 'BSE',
      symbol: '500112',
      isActive: false,
      category: 'EQUITY',
    });
  });
  it('lists both exchanges by default and updates only selected IDs', async () => {
    const instrument = {
      count: jest.fn().mockResolvedValue(2),
      findMany: jest.fn().mockResolvedValue([]),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    };
    const service = new InstrumentMasterService(
      {
        instrument,
        $transaction: (queries: any[]) => Promise.all(queries),
      } as any,
      { get: () => undefined } as any,
    );
    await service.list({});
    expect(instrument.count.mock.calls[0][0].where.exchange).toEqual({
      in: ['NSE', 'BSE'],
    });
    await service.list({ exchange: 'BSE' });
    expect(instrument.count.mock.calls[4][0].where.exchange).toEqual({
      in: ['BSE'],
    });
    await service.setBulkActiveByIds(['bse-id'], true);
    expect(instrument.updateMany.mock.calls[0][0].where.id).toEqual({
      in: ['bse-id'],
    });
  });
});
