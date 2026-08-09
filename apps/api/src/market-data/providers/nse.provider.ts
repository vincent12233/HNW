import { Injectable, Logger } from '@nestjs/common';
import axios, { AxiosInstance } from 'axios';

@Injectable()
export class NseProvider {
  private readonly logger = new Logger(NseProvider.name);

  private readonly client: AxiosInstance;


  constructor() {

    this.client = axios.create({

      baseURL: 'https://www.nseindia.com',

      timeout: 15000,

      headers: {

        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',

        Accept:
          'application/json,text/plain,*/*',

        Referer:
          'https://www.nseindia.com/',

      },

    });

  }



  async getQuote(symbol: string) {

    try {


      const response =
        await this.client.get(
          '/api/quote-equity',
          {
            params:{
              symbol,
            },
          },
        );


      const data =
        response.data;


      const price =
        data?.priceInfo?.lastPrice;


      const volume =
        data?.securityWiseDP?.quantityTraded ?? 0;



      if (
        price === undefined ||
        price === null
      ) {

        throw new Error(
          'NSE price missing',
        );

      }



      return {

        symbol,

        price:
          String(price),

        volume:
          String(volume),

        updatedAt:
          new Date(),

      };



    } catch(error:any) {


      this.logger.error(
        `NSE quote failed: ${symbol}`,
      );


      this.logger.error(
        JSON.stringify(
          {

            status:
              error?.response?.status,


            data:
              error?.response?.data,


            message:
              error?.message,

          },

          null,

          2,

        ),
      );


      throw error;

    }

  }

}