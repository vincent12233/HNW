import { IpoService } from './ipo.service';

describe('IpoService.listMyApplications debt payload', () => {
  it('includes debt amount/paidAmount/status when present', async () => {
    const prisma = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'acc',
          accountNumber: 'A1',
        }),
      },
      ipoApplication: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'app',
            status: 'ALLOTTED',
            paymentStatus: 'PENDING',
            allocatedQuantity: 10,
            allocatedPrice: { toFixed: () => '10.00' },
            allocatedAmount: { toFixed: () => '100.00' },
            createdAt: new Date('2026-01-01'),
            updatedAt: new Date('2026-01-01'),
            ipoDebt: {
              amount: { toFixed: (n: number) => (100).toFixed(n) },
              paidAmount: { toFixed: (n: number) => (40).toFixed(n) },
              status: 'PARTIAL',
            },
            ipo: {
              id: 'ipo',
              symbol: 'ACM',
              companyName: 'Acme',
              exchange: 'NSE',
              issuePrice: { toFixed: () => '10.00' },
              status: 'OPEN',
              openDate: new Date('2026-01-01'),
              closeDate: new Date('2026-01-10'),
            },
          },
        ]),
      },
    };
    const service = new IpoService(prisma as any);
    const result = await service.listMyApplications('user-1');
    expect(prisma.ipoApplication.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        include: expect.objectContaining({ ipoDebt: true }),
      }),
    );
    expect(result.data[0].debt).toEqual({
      amount: '100.00',
      paidAmount: '40.00',
      status: 'PARTIAL',
    });
  });

  it('returns null debt when application has none', async () => {
    const prisma = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'acc',
          accountNumber: 'A1',
        }),
      },
      ipoApplication: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'app',
            status: 'PENDING',
            paymentStatus: 'PENDING',
            allocatedQuantity: null,
            allocatedPrice: null,
            allocatedAmount: null,
            createdAt: new Date('2026-01-01'),
            updatedAt: new Date('2026-01-01'),
            ipoDebt: null,
            ipo: {
              id: 'ipo',
              symbol: 'ACM',
              companyName: 'Acme',
              exchange: 'NSE',
              issuePrice: { toFixed: () => '10.00' },
              status: 'OPEN',
              openDate: new Date('2026-01-01'),
              closeDate: new Date('2026-01-10'),
            },
          },
        ]),
      },
    };
    const service = new IpoService(prisma as any);
    const result = await service.listMyApplications('user-1');
    expect(result.data[0].debt).toBeNull();
  });
});
