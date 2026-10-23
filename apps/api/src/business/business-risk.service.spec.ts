import { UserRole } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { BusinessRiskService } from './business-risk.service';

describe('BusinessRiskService dashboard read contracts', () => {
  afterEach(() => jest.useRealTimers());

  it('scopes 24-hour dashboard counts to the assigned business customers', async () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-10-23T12:00:00.000Z'));
    const prisma = {
      loginAudit: {
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(3),
      },
      user: { count: jest.fn().mockResolvedValue(2) },
    } as unknown as PrismaService;
    const service = new BusinessRiskService(prisma);
    const ipSpy = jest
      .spyOn(service, 'sharedIpRisks')
      .mockResolvedValue([]);
    const deviceSpy = jest
      .spyOn(service, 'sharedDeviceRisks')
      .mockResolvedValue([]);
    const loginCount = jest.spyOn(prisma.loginAudit, 'count');
    const userCount = jest.spyOn(prisma.user, 'count');

    await expect(service.myRiskDashboard('business-1')).resolves.toEqual({
      sharedIpCustomers: 0,
      sharedDeviceCustomers: 0,
      failedLogin24h: 3,
      highRiskCustomers: 2,
    });

    const since = new Date('2026-10-22T12:00:00.000Z');
    expect(loginCount).toHaveBeenCalledWith({
      where: {
        success: false,
        createdAt: { gte: since },
        user: { assignedBusinessId: 'business-1' },
      },
    });
    expect(userCount).toHaveBeenCalledWith({
      where: {
        role: UserRole.CLIENT,
        assignedBusinessId: 'business-1',
        loginAudits: {
          some: {
            success: false,
            createdAt: { gte: since },
          },
        },
      },
    });
    expect(ipSpy).toHaveBeenCalledWith('business-1');
    expect(deviceSpy).toHaveBeenCalledWith('business-1');
  });

  it.each([
    [4, 'LOW'],
    [5, 'MEDIUM'],
    [9, 'MEDIUM'],
    [10, 'HIGH'],
  ] as const)(
    'preserves login risk threshold at %i failed attempts',
    async (failedCount, riskLevel) => {
      jest.useFakeTimers().setSystemTime(new Date('2026-10-23T12:00:00.000Z'));
      const customerFind = jest.fn().mockResolvedValue({
        id: 'customer-1',
        fullName: 'Test Customer',
      });
      const loginCount = jest.fn().mockResolvedValue(failedCount);
      const prisma = {
        user: { findFirst: customerFind },
        loginAudit: {
          count: loginCount,
          findFirst: jest.fn().mockResolvedValue(null),
        },
        $transaction: jest.fn((queries: Promise<unknown>[]) =>
          Promise.all(queries),
        ),
      } as unknown as PrismaService;

      const result = await new BusinessRiskService(prisma).customerLoginRisk(
        'business-1',
        'customer-1',
      );

      expect(customerFind).toHaveBeenCalledWith({
        where: {
          id: 'customer-1',
          role: UserRole.CLIENT,
          assignedBusinessId: 'business-1',
        },
        select: { id: true, fullName: true },
      });
      expect(loginCount).toHaveBeenCalledWith({
        where: {
          userId: 'customer-1',
          success: false,
          createdAt: { gte: new Date('2026-10-22T12:00:00.000Z') },
        },
      });
      expect(result.riskLevel).toBe(riskLevel);
    },
  );
});
