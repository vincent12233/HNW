import { ClientExperienceService } from './client-experience.service';
import sharp from 'sharp';

describe('Client profile and asset history', () => {
  it('updates membership and records previous and new tiers in one transaction', async () => {
    const tx = {
      user: { findUnique: jest.fn().mockResolvedValue({ role: 'CLIENT', clientTier: 'STANDARD' }),
        update: jest.fn().mockResolvedValue({ id: 'client', clientTier: 'GOLD' }) },
      auditLog: { create: jest.fn() },
    };
    const service = new ClientExperienceService({ $transaction: (fn: any) => fn(tx) } as any);
    await expect(service.updateTier('admin', 'client', 'GOLD')).resolves.toEqual({ id: 'client', clientTier: 'GOLD' });
    expect(tx.auditLog.create).toHaveBeenCalledWith({ data: expect.objectContaining({ actorId: 'admin',
      resourceId: 'client', metadata: { previous: 'STANDARD', tier: 'GOLD' } }) });
    await expect(service.updateTier('admin', 'client', 'VIP')).rejects.toThrow('Invalid client tier');
    tx.user.findUnique.mockResolvedValue({ role: 'ADMIN', clientTier: 'STANDARD' });
    await expect(service.updateTier('admin', 'client', 'SILVER')).rejects.toThrow('Client not found');
    expect(tx.user.update).toHaveBeenCalledTimes(1);
  });
  it('rejects arbitrary avatar payloads and stores a resized raster image', async () => {
    const update = jest.fn(async ({ data }: any) => data);
    const service = new ClientExperienceService({ user: { update } } as any);
    await expect(service.updateAvatar('client', Buffer.from('<svg/>').toString('base64'))).rejects.toThrow('valid JPEG');
    const png = await sharp({ create: { width: 10, height: 20, channels: 3, background: '#ff0000' } }).png().toBuffer();
    const result = await service.updateAvatar('client', png.toString('base64'));
    const metadata = await sharp(Buffer.from(result.avatarData!, 'base64')).metadata();
    expect(metadata).toMatchObject({ format: 'webp', width: 256, height: 256 });
    expect(update).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'client' } }));
  });
  it('rejects unsupported languages and themes without writing preferences', async () => {
    const service = new ClientExperienceService({} as any);
    await expect(service.updatePreferences('client', { language: 'xx' })).rejects.toThrow('Unsupported language');
    await expect(service.updatePreferences('client', { theme: 'fake' })).rejects.toThrow('Unsupported theme');
  });
  it('updates only the name and never requires or changes email', async () => {
    const update = jest.fn().mockResolvedValue({ fullName: 'Asha Kumar' });
    const service = new ClientExperienceService({ user: { update } } as any);
    await service.updateProfile('client', { fullName: ' Asha Kumar ', email: 'ignored@example.test' });
    expect(update.mock.calls[0][0].data).toEqual({ fullName: 'Asha Kumar' });
  });
  it('excludes ordinary stocks and cash from product value but includes them in total assets', async () => {
    const capturedAt = new Date();
    const create = jest.fn().mockResolvedValue({});
    const tx = {
      account: { findUnique: jest.fn().mockResolvedValue({ id: 'account', cashBalance: 100, positions: [
        { quantity: 2, averagePrice: 10, realizedPnl: 5, instrument: { category: 'IT', quote: { lastPrice: 12 } } },
        { quantity: 3, averagePrice: 20, realizedPnl: 0, instrument: { category: 'IPO', quote: { lastPrice: 25 } } },
      ] }) },
      portfolioSnapshot: { findFirst: jest.fn().mockResolvedValue(null), create, findMany: jest.fn().mockResolvedValue([
        { capturedAt, profitValue: 10, totalValue: 150, instValue: 0, otcValue: 0, ipoValue: 60 },
        { capturedAt, profitValue: 24, totalValue: 199, instValue: 0, otcValue: 0, ipoValue: 75 },
      ]) },
    };
    const service = new ClientExperienceService({ $transaction: (fn: any) => fn(tx) } as any);
    const result = await service.assetHistory('client', '1W');
    const snapshot = create.mock.calls[0][0].data;
    expect(snapshot.totalValue.toString()).toBe('199');
    expect(snapshot.ipoValue.toString()).toBe('75');
    expect(snapshot.profitValue.toString()).toBe('24');
    expect(result.profitChange).toBe(14);
    expect(result.points[1].productValue).toBe(75);
  });
  it('rejects unrecognized periods before database work', async () => {
    const service = new ClientExperienceService({} as any);
    await expect(service.assetHistory('client', 'constructor')).rejects.toThrow('Unsupported period');
  });
});
