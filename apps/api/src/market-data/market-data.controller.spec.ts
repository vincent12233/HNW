import { Test, TestingModule } from '@nestjs/testing';
import { MarketDataController } from './market-data.controller';

describe('MarketDataController', () => {
  let controller: MarketDataController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [MarketDataController],
    }).compile();

    controller = module.get<MarketDataController>(MarketDataController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
