import { LoansService } from './loans.service';
import { UserRole } from '../generated/prisma/enums';

describe('Loan record visibility', () => {
  function fixture() {
    const findMany = jest.fn().mockResolvedValue([]);
    const service = new LoansService(
      { loanApplication: { findMany } } as any,
      {} as any,
    );
    return { service, findMany };
  }

  it.each(['client-a', 'client-b'])('limits client records to %s and excludes internal fields', async (userId) => {
    const { service, findMany } = fixture();
    await service.clientLoans(userId);
    const query = findMany.mock.calls[0][0];
    expect(query.where).toEqual({ account: { userId } });
    expect(Object.keys(query.select).sort()).toEqual([
      'id', 'orderNo', 'status', 'approvedAmount', 'outstandingAmount', 'createdAt',
    ].sort());
    expect(query.include).toBeUndefined();
  });

  it.each(['business-a', 'business-b'])('retains ownership for %s when searching', async (userId) => {
    const { service, findMany } = fixture();
    await service.list(userId, UserRole.BUSINESS, { search: ' outside-client ', status: 'PENDING' });
    const { where } = findMany.mock.calls[0][0];
    expect(where.account).toEqual({ user: { assignedBusinessId: userId } });
    expect(where.status).toBe('PENDING');
    expect(where.OR).toContainEqual({ orderNo: { contains: 'outside-client', mode: 'insensitive' } });
  });

  it('preserves finance fixed-invite exclusion during search', async () => {
    const { service, findMany } = fixture();
    await service.list('finance', UserRole.FINANCE, { search: 'customer' });
    const fixedCode = process.env.ADMIN_FIXED_INVITE_CODE?.trim().toUpperCase() || 'ADMINFIXED2026';
    expect(findMany.mock.calls[0][0].where.account).toEqual({
      user: { NOT: { usedInviteCode: { is: { code: fixedCode } } } },
    });
  });
});
