import { ListInstrumentsQueryDto } from './dto/list-instruments-query.dto';

describe('public ListInstrumentsQueryDto featured filters', () => {
  it('accepts featuredHome and featuredMarkets query flags', () => {
    const dto: ListInstrumentsQueryDto = {
      featuredHome: true,
      featuredMarkets: false,
      type: undefined,
      limit: 20,
    };
    expect(dto.featuredHome).toBe(true);
    expect(dto.featuredMarkets).toBe(false);
    expect(dto.limit).toBe(20);
  });
});
