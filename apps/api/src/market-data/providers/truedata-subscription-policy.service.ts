import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class TrueDataSubscriptionPolicyService {
  constructor(private readonly config: ConfigService) {}

  validateAndBatch(symbols: string[]) {
    const unique = [...new Set(symbols.map((item) => item.trim()).filter(Boolean))];
    const planLimit = this.positiveInteger(
      this.config.get<string>('TRUEDATA_SYMBOL_LIMIT'),
      200,
    );
    const batchSize = Math.min(
      this.positiveInteger(this.config.get<string>('TRUEDATA_SUBSCRIBE_BATCH_SIZE'), 50),
      planLimit,
    );

    if (unique.length > planLimit) {
      throw new BadRequestException(
        `TrueData subscription count ${unique.length} exceeds configured plan limit ${planLimit}`,
      );
    }

    const batches: string[][] = [];
    for (let index = 0; index < unique.length; index += batchSize) {
      batches.push(unique.slice(index, index + batchSize));
    }

    return {
      symbols: unique,
      batches,
      planLimit,
      batchSize,
    };
  }

  private positiveInteger(value: string | undefined, fallback: number) {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
