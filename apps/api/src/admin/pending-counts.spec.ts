import { AdminService } from './admin.service';
import { UserRole } from '../generated/prisma/enums';

describe('Manager pending counts ownership', () => {
  it.each(['manager-a', 'manager-b'])(
    'scopes all customer counts to %s and excludes deleted staff',
    async (managerId) => {
      const count = () => ({ count: jest.fn().mockResolvedValue(1) });
      const prisma = {
        $queryRaw: jest.fn().mockResolvedValue([{ count: BigInt(1) }]),
        depositRequest: count(),
        withdrawalRequest: count(),
        loanApplication: count(),
        otcOrder: count(),
        ipoApplication: count(),
        approvalRequest: count(),
      };
      const result = await new AdminService(prisma as any).pendingCounts(
        UserRole.MANAGER,
        managerId,
      );
      for (const model of [
        prisma.depositRequest,
        prisma.withdrawalRequest,
        prisma.otcOrder,
        prisma.ipoApplication,
      ]) {
        expect(model.count).toHaveBeenCalledWith({
          where: {
            status: 'PENDING',
            account: {
              user: {
                assignedBusiness: {
                  role: UserRole.BUSINESS,
                  businessCreatorId: managerId,
                  deletedAt: null,
                },
              },
            },
          },
        });
      }
      const query = prisma.$queryRaw.mock.calls[0] as unknown as [
        string[],
        { strings: string[]; values: unknown[] },
      ];
      expect(query[1].values).toContain(managerId);
      expect(query[1].strings.join('')).toContain('"deletedAt" IS NULL');
      expect(prisma.approvalRequest.count).not.toHaveBeenCalled();
      expect(prisma.loanApplication.count).not.toHaveBeenCalled();
      expect(result.loans).toBe(0);
      expect(result.total).toBe(5);
    },
  );
});
