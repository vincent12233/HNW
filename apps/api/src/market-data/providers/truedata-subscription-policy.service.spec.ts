import { BadRequestException } from '@nestjs/common';
import { TrueDataSubscriptionPolicyService } from './truedata-subscription-policy.service';

describe('TrueDataSubscriptionPolicyService', () => {
  it('deduplicates and batches symbols within the configured limit', () => {
    const config = {
      get: jest.fn((key: string) => {
        if (key === 'TRUEDATA_SYMBOL_LIMIT') return '5';
        if (key === 'TRUEDATA_SUBSCRIBE_BATCH_SIZE') return '2';
        return undefined;
      }),
    } as any;
    const service = new TrueDataSubscriptionPolicyService(config);

    const result = service.validateAndBatch([
      'RELIANCE',
      'TCS',
      'RELIANCE',
      'HDFCBANK',
    ]);

    expect(result.symbols).toEqual(['RELIANCE', 'TCS', 'HDFCBANK']);
    expect(result.batches).toEqual([['RELIANCE', 'TCS'], ['HDFCBANK']]);
  });

  it('rejects subscriptions above the configured plan limit', () => {
    const config = {
      get: jest.fn((key: string) =>
        key === 'TRUEDATA_SYMBOL_LIMIT' ? '2' : undefined,
      ),
    } as any;
    const service = new TrueDataSubscriptionPolicyService(config);

    expect(() =>
      service.validateAndBatch(['RELIANCE', 'TCS', 'HDFCBANK']),
    ).toThrow(BadRequestException);
  });
});
