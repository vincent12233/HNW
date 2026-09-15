import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { LoansService } from './loans.service';
import { UserRole } from '../generated/prisma/enums';
import { LoansController } from './loans.controller';
import { ROLES_KEY } from '../auth/roles.decorator';

describe('loan application rules', () => {
  it.each([0, -1, NaN, Infinity, true, 'abc', 0.001, 100.999, 1e16])(
    'rejects invalid finance amount %s before database access',
    async (amount) => {
      const service = new LoansService({} as any, {} as any);
      await expect(
        service.create('finance', UserRole.FINANCE, {
          accountNumber: 'A',
          amount: amount as number,
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
      await expect(
        service.approve('loan', 'finance', UserRole.FINANCE, {
          approvedAmount: amount as number,
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
    },
  );
  it('only finance has mutation routes; business can read and support cannot', () => {
    for (const key of [
      'create',
      'approve',
      'reject',
      'disburse',
      'repay',
      'overdue',
    ] as const) {
      expect(
        Reflect.getMetadata(ROLES_KEY, LoansController.prototype[key]),
      ).toEqual([UserRole.FINANCE]);
    }
    const readers = Reflect.getMetadata(
      ROLES_KEY,
      LoansController.prototype.list,
    );
    expect(readers).toContain(UserRole.BUSINESS);
    expect(readers).not.toContain(UserRole.SUPPORT);
    expect(
      Reflect.getMetadata(ROLES_KEY, LoansController.prototype.apply),
    ).toEqual([UserRole.CLIENT]);
  });
  it.each([UserRole.BUSINESS, UserRole.SUPPORT, UserRole.ADMIN])(
    'denies staff creation for %s',
    async (role) => {
      const service = new LoansService({} as any, {} as any);
      await expect(
        service.create('staff', role, { accountNumber: 'A', amount: 10 }),
      ).rejects.toBeInstanceOf(ForbiddenException);
    },
  );
  it('creates an amount-free request and reuses a pending application', async () => {
    const tx = {
      account: { findUnique: jest.fn().mockResolvedValue({ id: 'account' }) },
      $queryRaw: jest.fn(),
      loanApplication: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce(null)
          .mockResolvedValueOnce({ id: 'loan', status: 'PENDING' }),
        create: jest.fn().mockResolvedValue({ id: 'loan', status: 'PENDING' }),
      },
    };
    const service = new LoansService(
      { $transaction: (fn: any) => fn(tx) } as any,
      {} as any,
    );
    await service.apply('client');
    await service.apply('client');
    expect(tx.loanApplication.create).toHaveBeenCalledTimes(1);
    expect(tx.loanApplication.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        accountId: 'account',
        requestedAmount: 0,
      }),
    });
  });
});
