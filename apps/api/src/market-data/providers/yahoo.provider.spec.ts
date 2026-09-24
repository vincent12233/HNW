import axios from 'axios';
import { YahooProvider } from './yahoo.provider';

jest.mock('axios');

const mockedAxios = jest.mocked(axios);

describe('YahooProvider index symbols', () => {
  beforeEach(() => {
    mockedAxios.get.mockReset();
    mockedAxios.get.mockResolvedValue({
      data: {
        chart: {
          result: [
            {
              timestamp: [1_700_000_000],
              indicators: {
                quote: [
                  {
                    open: [100],
                    high: [102],
                    low: [99],
                    close: [101],
                    volume: [1000],
                  },
                ],
              },
            },
          ],
        },
      },
    });
  });

  it.each([
    ['NIFTY50', 'NSE', '%5ENSEI'],
    ['SENSEX', 'BSE', '%5EBSESN'],
    ['BANKNIFTY', 'NSE', '%5ENSEBANK'],
    ['INDIAVIX', 'NSE', '%5EINDIAVIX'],
  ])(
    'uses the index ticker for %s history',
    async (symbol, exchange, ticker) => {
      await new YahooProvider().getHistory(symbol, exchange, '1D');

      expect(mockedAxios.get).toHaveBeenCalledWith(
        expect.stringContaining(`/chart/${ticker}`),
        expect.any(Object),
      );
    },
  );

  it('keeps exchange suffixes for stock history', async () => {
    await new YahooProvider().getHistory('RELIANCE', 'NSE', '1D');

    expect(mockedAxios.get).toHaveBeenCalledWith(
      expect.stringContaining('/chart/RELIANCE.NS'),
      expect.any(Object),
    );
  });
});
