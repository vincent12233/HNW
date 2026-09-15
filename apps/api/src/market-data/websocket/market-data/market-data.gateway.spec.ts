import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../../prisma/prisma.service';
import { MarketDataGateway } from './market-data.gateway';

describe('MarketDataGateway', () => {
  let gateway: MarketDataGateway;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MarketDataGateway,
        { provide: JwtService, useValue: { verifyAsync: jest.fn() } },
        {
          provide: PrismaService,
          useValue: { user: { findUnique: jest.fn() } },
        },
      ],
    }).compile();

    gateway = module.get<MarketDataGateway>(MarketDataGateway);
  });

  it('should be defined', () => {
    expect(gateway).toBeDefined();
  });
});
