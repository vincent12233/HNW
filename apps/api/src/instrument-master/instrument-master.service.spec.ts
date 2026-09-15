import axios from 'axios';
import {
  categoryForEquityMasterUpdate,
  InstrumentMasterService,
} from './instrument-master.service';

describe('categoryForEquityMasterUpdate', () => {
  it('preserves institutional, OTC and IPO categories', () => {
    expect(categoryForEquityMasterUpdate('INSTITUTIONAL')).toBe('INSTITUTIONAL');
    expect(categoryForEquityMasterUpdate('INST')).toBe('INST');
    expect(categoryForEquityMasterUpdate('LIMIT_UP')).toBe('LIMIT_UP');
    expect(categoryForEquityMasterUpdate('OTC')).toBe('OTC');
    expect(categoryForEquityMasterUpdate('BLOCK_TRADE')).toBe('BLOCK_TRADE');
    expect(categoryForEquityMasterUpdate('IPO')).toBe('IPO');
  });

  it('defaults ordinary or unknown categories to EQUITY', () => {
    expect(categoryForEquityMasterUpdate('EQUITY')).toBe('EQUITY');
    expect(categoryForEquityMasterUpdate('equity')).toBe('EQUITY');
    expect(categoryForEquityMasterUpdate(null)).toBe('EQUITY');
    expect(categoryForEquityMasterUpdate('')).toBe('EQUITY');
    expect(categoryForEquityMasterUpdate('OTHER')).toBe('EQUITY');
  });
});

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
        .mockResolvedValueOnce({ id: 'existing-reliance', category: 'EQUITY' })
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
        data: expect.objectContaining({
          category: 'EQUITY',
        }),
      }),
    );
    expect(instrument.update.mock.calls[0][0].data.isActive).toBeUndefined();
    expect(instrument.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          symbol: 'NEWCO',
          isActive: false,
          category: 'EQUITY',
        }),
      }),
    );
  });

  it('preserves INSTITUTIONAL category when syncing an existing NSE symbol', async () => {
    jest.spyOn(axios, 'get').mockResolvedValue({ data: csv } as any);
    const instrument = {
      findUnique: jest
        .fn()
        .mockResolvedValueOnce({
          id: 'existing-reliance',
          category: 'INSTITUTIONAL',
        })
        .mockResolvedValueOnce(null),
      update: jest.fn().mockResolvedValue({}),
      create: jest.fn().mockResolvedValue({}),
    };
    const service = new InstrumentMasterService(
      { instrument } as any,
      { get: jest.fn().mockReturnValue(undefined) } as any,
    );

    await service.syncNseEquities();

    expect(instrument.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ category: 'INSTITUTIONAL' }),
      }),
    );
  });

  it('preserves OTC and IPO categories on BSE sync updates', async () => {
    const bseCsv = [
      'SECURITY CODE,SECURITY NAME,ISIN NO,MARKET LOT',
      '500325,Reliance Industries,INE002A01018,1',
      '500570,Tata Motors,INE155A01022,1',
    ].join('\n');
    jest.spyOn(axios, 'get').mockResolvedValue({ data: bseCsv } as any);
    const instrument = {
      findUnique: jest
        .fn()
        .mockResolvedValueOnce({ id: 'bse-1', category: 'OTC' })
        .mockResolvedValueOnce({ id: 'bse-2', category: 'IPO' }),
      update: jest.fn().mockResolvedValue({}),
      create: jest.fn().mockResolvedValue({}),
    };
    const service = new InstrumentMasterService(
      { instrument } as any,
      { get: jest.fn().mockReturnValue('https://example.test/bse.csv') } as any,
    );

    const result = await service.syncBseEquities();
    expect(result.updated).toBe(2);
    expect(instrument.update.mock.calls[0][0].data.category).toBe('OTC');
    expect(instrument.update.mock.calls[1][0].data.category).toBe('IPO');
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
