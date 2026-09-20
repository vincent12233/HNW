import { Prisma } from '../generated/prisma/client';
import { sumCumulativeConfirmedDeposit } from './vip-cumulative-deposit';

describe('cumulative confirmed deposit', () => {
  it('adds approved deposit requests and finance/support credits only', async () => {
    const db = {
      depositRequest: {
        aggregate: jest.fn().mockResolvedValue({
          _sum: { amount: new Prisma.Decimal('1000.50') },
        }),
      },
      accountTransaction: {
        aggregate: jest.fn().mockResolvedValue({
          _sum: { amount: new Prisma.Decimal('250.25') },
        }),
      },
    };
    await expect(sumCumulativeConfirmedDeposit(db, 'acct-1')).resolves.toEqual(
      new Prisma.Decimal('1250.75'),
    );
    expect(db.depositRequest.aggregate).toHaveBeenCalledWith({
      where: { accountId: 'acct-1', status: 'APPROVED' },
      _sum: { amount: true },
    });
    expect(db.accountTransaction.aggregate).toHaveBeenCalledWith({
      where: {
        accountId: 'acct-1',
        type: 'ADMIN_CREDIT',
        status: 'COMPLETED',
        createdBy: { is: { role: { in: ['FINANCE', 'SUPPORT'] } } },
      },
      _sum: { amount: true },
    });
  });

  it('returns zero when the client has no account', async () => {
    await expect(sumCumulativeConfirmedDeposit({} as never, null)).resolves.toEqual(
      new Prisma.Decimal('0.00'),
    );
  });
});
