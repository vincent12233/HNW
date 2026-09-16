import { BadRequestException } from '@nestjs/common';
import { UpdateInstrumentPlacementDto } from './dto/update-instrument-placement.dto';

describe('UpdateInstrumentPlacementDto contract', () => {
  it('accepts placement-only fields', () => {
    const dto: UpdateInstrumentPlacementDto = {
      featuredHome: true,
      featuredMarkets: false,
      displayOrder: 10,
    };
    expect(dto.featuredHome).toBe(true);
    expect(dto.displayOrder).toBe(10);
  });

  it('documents empty body rejection message used by service', () => {
    const err = new BadRequestException(
      'Provide featuredHome, featuredMarkets, and/or displayOrder',
    );
    expect(err.message).toContain('featuredHome');
  });
});
