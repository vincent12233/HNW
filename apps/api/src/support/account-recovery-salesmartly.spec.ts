import { BadRequestException } from '@nestjs/common';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { AccountRecoveryService } from './account-recovery.service';

describe('SaleSmartly account-recovery handoff', () => {
  it('keeps the legacy internal chat runtime dormant', () => {
    const moduleSource = readFileSync(
      join(process.cwd(), 'src', 'support', 'support.module.ts'),
      'utf8',
    );
    expect(moduleSource).not.toMatch(
      /SupportController|SupportService|SupportGateway/,
    );
    expect(moduleSource).toMatch(/AccountRecoveryController/);
  });

  const session = {
    id: '11111111-1111-4111-8111-111111111111',
    phone: '919876543210',
    status: 'OPEN',
    expiresAt: new Date(Date.now() + 60_000),
    codeHash: null,
    codeExpiresAt: null,
    codeUsedAt: null,
    codeAttempts: 0,
    issuedUserId: null,
  };

  function subject() {
    const tx = {
      $queryRaw: jest.fn().mockResolvedValue([session]),
      $executeRaw: jest.fn().mockResolvedValue(1),
      user: {
        findFirst: jest.fn().mockResolvedValue({ id: 'client-1' }),
      },
      auditLog: { create: jest.fn().mockResolvedValue({}) },
    };
    const prisma = {
      $transaction: jest.fn(async (callback: (value: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    return {
      service: new AccountRecoveryService(prisma as never),
      prisma,
      tx,
    };
  }

  it('rejects issuance without a safe external interaction reference', async () => {
    const { service, prisma } = subject();
    await expect(
      service.issue(session.id, 'support-1', true, '../../token=secret'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('stores only the reference and audits issuance, never chat content', async () => {
    const { service, tx } = subject();
    const result = await service.issue(
      session.id,
      'support-1',
      true,
      'ss-conversation-42',
    );

    expect(result.code).toMatch(/^[A-F0-9]{12}$/);
    expect(tx.$executeRaw).toHaveBeenCalledTimes(3);
    const serializedCalls = JSON.stringify(tx.$executeRaw.mock.calls);
    expect(serializedCalls).toContain('support_interaction_references');
    expect(serializedCalls).toContain('ss-conversation-42');
    expect(serializedCalls).not.toContain('chat history');
    expect(tx.auditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          action: 'SUPPORT_PASSWORD_RESET_ISSUED',
          resourceId: session.id,
        }),
      }),
    );
  });
});
