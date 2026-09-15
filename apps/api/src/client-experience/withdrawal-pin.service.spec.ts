import * as bcrypt from 'bcrypt';
import { WithdrawalPinService } from './withdrawal-pin.service';

describe('WithdrawalPinService', () => {
  let service: WithdrawalPinService;
  let user: any;
  let tx: any;
  beforeEach(async () => {
    user = {
      id: 'client',
      passwordHash: await bcrypt.hash('login-password', 4),
      withdrawalPinHash: null,
      withdrawalPinAttempts: 0,
      withdrawalPinLockedUntil: null,
    };
    tx = {
      $queryRaw: jest.fn().mockResolvedValue([]),
      user: {
        findUnique: jest.fn(async () => user),
        update: jest.fn(async ({ data }) => {
          Object.assign(user, data);
          return user;
        }),
      },
    };
    service = new WithdrawalPinService({
      $transaction: (fn: any) => fn(tx),
      user: tx.user,
    } as any);
  });
  it('requires setup before withdrawing', async () => {
    await expect(service.verify('client', '123456')).rejects.toThrow(
      'Set your withdrawal PIN',
    );
  });
  it('sets a hashed PIN only with the login password', async () => {
    await expect(
      service.change('client', {
        currentPassword: 'incorrect',
        newPin: '123456',
      }),
    ).rejects.toThrow('Incorrect');
    expect(user.withdrawalPinHash).toBeNull();
    await service.change('client', {
      currentPassword: 'login-password',
      newPin: '123456',
    });
    expect(user.withdrawalPinHash).not.toBe('123456');
    await expect(service.verify('client', '123456')).resolves.toBeUndefined();
  });
  it('requires the old PIN to change an existing PIN', async () => {
    user.withdrawalPinHash = await bcrypt.hash('123456', 4);
    await expect(
      service.change('client', {
        currentPassword: 'login-password',
        currentPin: '000000',
        newPin: '654321',
      }),
    ).rejects.toThrow('Incorrect');
    await service.change('client', {
      currentPassword: 'login-password',
      currentPin: '123456',
      newPin: '654321',
    });
    await expect(service.verify('client', '123456')).rejects.toThrow(
      'Incorrect',
    );
    await expect(service.verify('client', '654321')).resolves.toBeUndefined();
  });
  it('persists a lock after five failures and permits retry after expiry', async () => {
    user.withdrawalPinHash = await bcrypt.hash('123456', 4);
    for (let i = 0; i < 5; i++)
      await expect(service.verify('client', '000000')).rejects.toThrow(
        'Incorrect',
      );
    expect(user.withdrawalPinAttempts).toBe(5);
    await expect(service.verify('client', '123456')).rejects.toThrow(
      '15 minutes',
    );
    user.withdrawalPinLockedUntil = new Date(Date.now() - 1);
    await service.verify('client', '123456');
    expect(user.withdrawalPinAttempts).toBe(0);
  });
  it('rejects malformed new PINs', async () => {
    for (const newPin of ['123', 'abcdef', 123456, '1234567']) {
      await expect(
        service.change('client', { currentPassword: 'login-password', newPin }),
      ).rejects.toThrow('6 digits');
    }
    expect(tx.$queryRaw).not.toHaveBeenCalled();
  });
});
