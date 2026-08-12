import axios from 'axios';
import { InstrumentMasterService } from './instrument-master.service';

describe('InstrumentMasterService', () => {
  const csv = [
    'SYMBOL,NAME OF COMPANY,SERIES,DATE OF LISTING,PAID UP VALUE,MARKET LOT,ISIN NUMBER,FACE VALUE',
    'RELIANCE,Reliance Industries Limited,EQ,29-NOV-1995,10,1,INE002A01018,10',
    'NEWCO,"New Company, Limited",EQ,01-JAN-2026,10,1,INE000A01000,10',
    'BEONLY,BE Only Limited,BE,01-JAN-2020,10,1,INE000B01000,10',
  ].join('\n');

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('parses the NSE equity CSV including quoted company names', () => {
    const service = new InstrumentMasterService(
      {} as any,
      { get: jest.fn() } as any,
    );

    expect(service.parseNseEquityCsv(csv)).toEqual([
      expect.objectContaining({
        symbol: 'RELIANCE',
        name: 'Reliance Industries Limited',
        series: 'EQ',
        isin: 'INE002A01018',
        lotSize: 1,
      }),
      expect.objectContaining({
        symbol: 'NEWCO',
        name: 'New Company, Limited',
        series: 'EQ',
      }),
      expect.objectContaining({ symbol: 'BEONLY', series: 'BE' }),
    ]);
  });

  it('updates existing EQ metadata without changing activation and creates new symbols inactive', async () => {
    jest.spyOn(axios, 'get').mockResolvedValue({ data: csv } as any);

    const instrument = {
      findUnique: jest
        .fn()
        .mockResolvedValueOnce({ id: 'existing-reliance' })
        .mockResolvedValueOnce(null),
      update: jest.fn().mockResolvedValue({}),
      create: jest.fn().mockResolvedValue({}),
    };
    const service = new InstrumentMasterService(
      { instrument } as any,
      { get: jest.fn().mockReturnValue(undefined) } as any,
    );

    const result = await service.syncNseEquities();

    expect(result).toEqual(
      expect.objectContaining({ totalRows: 2, created: 1, updated: 1 }),
    );
    expect(instrument.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'existing-reliance' },
        data: expect.not.objectContaining({ isActive: expect.anything() }),
      }),
    );
    expect(instrument.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          symbol: 'NEWCO',
          isActive: false,
        }),
      }),
    );
  });

  it('bulk activation normalizes and deduplicates symbols', async () => {
    const instrument = {
      updateMany: jest.fn().mockResolvedValue({ count: 2 }),
    };
    const service = new InstrumentMasterService(
      { instrument } as any,
      { get: jest.fn() } as any,
    );

    const result = await service.setBulkActive(
      [' reliance ', 'TCS', 'RELIANCE', ''],
      true,
    );

    expect(result).toEqual({
      updated: 2,
      symbols: ['RELIANCE', 'TCS'],
      isActive: true,
    });
    expect(instrument.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { isActive: true },
        where: expect.objectContaining({
          symbol: { in: ['RELIANCE', 'TCS'] },
        }),
      }),
    );
  });
});
