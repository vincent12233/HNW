import { applyManualVipTierChange } from './vip-tier-change';
import { Prisma } from '../generated/prisma/client';

function txMock(overrides: Record<string, unknown> = {}) {
  return {
    $executeRaw: jest.fn().mockResolvedValue(undefined),
    user: {
      findFirst: jest.fn().mockResolvedValue({
        id: 'client-1',
        role: 'CLIENT',
        clientTier: 'STANDARD',
        account: { id: 'acct-1' },
      }),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    vipTierHistory: {
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue({ id: 'hist-1' }),
    },
    vipTierConfiguration: {
      findMany: jest.fn().mockResolvedValue([
        {
          tierCode: 'STANDARD',
          displayOrder: 1,
          isActive: true,
          minimumCumulativeDeposit: null,
          updatedAt: new Date('2026-09-19T00:00:00.000Z'),
        },
      ]),
    },
    depositRequest: {
      aggregate: jest
        .fn()
        .mockResolvedValue({ _sum: { amount: new Prisma.Decimal('0') } }),
    },
    accountTransaction: {
      aggregate: jest
        .fn()
        .mockResolvedValue({ _sum: { amount: new Prisma.Decimal('0') } }),
    },
    auditLog: { create: jest.fn() },
    ...overrides,
  };
}

describe('manual VIP tier change', () => {
  it('updates the client, writes history, and audits in one transaction', async () => {
    const tx = txMock();
    await expect(
      applyManualVipTierChange(tx as never, {
        actorId: 'admin-1',
        userId: 'client-1',
        tier: 'GOLD',
        reason: 'Relationship review',
        source: 'ADMIN',
        requireReason: false,
      }),
    ).resolves.toEqual({ id: 'client-1', clientTier: 'GOLD' });
    expect(tx.user.updateMany).toHaveBeenCalledWith({
      where: { id: 'client-1', role: 'CLIENT', deletedAt: null },
      data: { clientTier: 'GOLD' },
    });
    expect(tx.vipTierHistory.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        userId: 'client-1',
        previousTier: 'STANDARD',
        newTier: 'GOLD',
        source: 'ADMIN',
        reason: 'Relationship review',
      }),
    });
    expect(tx.auditLog.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: 'CLIENT_TIER_UPDATED',
        metadata: expect.objectContaining({
          previous: 'STANDARD',
          tier: 'GOLD',
        }),
      }),
    });
  });

  it('scopes business adjustments to assigned customers', async () => {
    const tx = txMock({
      user: {
        findFirst: jest.fn().mockResolvedValue(null),
        updateMany: jest.fn(),
      },
    });
    await expect(
      applyManualVipTierChange(tx as never, {
        actorId: 'business-1',
        userId: 'other-client',
        tier: 'GOLD',
        reason: 'Team review note',
        source: 'MANUAL',
        requireReason: true,
      }),
    ).rejects.toThrow('Customer not assigned to this business user');
    expect(tx.user.updateMany).not.toHaveBeenCalled();
    expect(tx.vipTierHistory.create).not.toHaveBeenCalled();
  });

  it('requires a reason on the dedicated business VIP path', async () => {
    await expect(
      applyManualVipTierChange(txMock() as never, {
        actorId: 'business-1',
        userId: 'client-1',
        tier: 'GOLD',
        reason: ' ',
        source: 'MANUAL',
        requireReason: true,
      }),
    ).rejects.toThrow('Adjustment reason is required');
  });

  it('replays a duplicate submit without a second write', async () => {
    const tx = txMock({
      user: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'client-1',
          role: 'CLIENT',
          clientTier: 'GOLD',
          account: { id: 'acct-1' },
        }),
        updateMany: jest.fn(),
      },
      vipTierHistory: {
        findFirst: jest.fn().mockResolvedValue({ id: 'hist-1' }),
        create: jest.fn(),
      },
    });
    await expect(
      applyManualVipTierChange(tx as never, {
        actorId: 'admin-1',
        userId: 'client-1',
        tier: 'GOLD',
        reason: 'Relationship review',
        source: 'ADMIN',
        requireReason: false,
      }),
    ).resolves.toEqual({ id: 'client-1', clientTier: 'GOLD' });
    expect(tx.user.updateMany).not.toHaveBeenCalled();
    expect(tx.vipTierHistory.create).not.toHaveBeenCalled();
  });
});
