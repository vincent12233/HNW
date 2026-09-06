import { BadRequestException, NotFoundException } from '@nestjs/common';
import { KycService, type KycSubmissionInput } from './kyc.service';
import { PrismaService } from '../prisma/prisma.service';
import { PrivateObjectStorageService } from '../storage/private-object-storage.service';

const png =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ZkAAAAASUVORK5CYII=';
const submission: KycSubmissionInput = {
  documentType: 'PAN',
  fileName: 'pan.png',
  mimeType: 'image/png',
  contentBase64: png,
  selfieContentBase64: png,
  selfieMimeType: 'image/png',
  signatureContentBase64: png,
};

describe('KYC evidence', () => {
  const prisma = {
    user: { findUnique: jest.fn() },
    $executeRaw: jest.fn(),
    $queryRaw: jest.fn(),
  };
  const objects = { putKyc: jest.fn(), get: jest.fn(), remove: jest.fn() };
  const service = new KycService(
    prisma as unknown as PrismaService,
    objects as unknown as PrivateObjectStorageService,
  );

  beforeEach(() => {
    jest.resetAllMocks();
    prisma.user.findUnique.mockResolvedValue({
      id: 'customer',
      assignedBusinessId: 'owner',
    });
    objects.putKyc.mockImplementation(
      async (_user: string, _bytes: Buffer, mime: string) => ({
        key: `private/${objects.putKyc.mock.calls.length}`,
        mime,
      }),
    );
    prisma.$executeRaw.mockResolvedValue(1);
  });

  it.each(['selfieContentBase64', 'signatureContentBase64'] as const)(
    'rejects missing %s before storing files',
    async (field) => {
      await expect(
        service.submit('customer', { ...submission, [field]: '' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(objects.putKyc).not.toHaveBeenCalled();
      expect(prisma.$executeRaw).not.toHaveBeenCalled();
    },
  );

  it.each([
    ['selfieContentBase64', 2 * 1024 * 1024 + 1],
    ['signatureContentBase64', 1024 * 1024 + 1],
  ] as const)('rejects oversized %s', async (field, size) => {
    await expect(
      service.submit('customer', {
        ...submission,
        [field]: Buffer.alloc(size).toString('base64'),
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(objects.putKyc).not.toHaveBeenCalled();
  });

  it('rejects PDF selfies and requires both Aadhaar sides', async () => {
    await expect(
      service.submit('customer', {
        ...submission,
        selfieMimeType: 'application/pdf',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      service.submit('customer', { ...submission, documentType: 'AADHAAR' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(objects.putKyc).not.toHaveBeenCalled();
  });

  it('persists three private objects together with a pending submission', async () => {
    await expect(service.submit('customer', submission)).resolves.toMatchObject(
      { status: 'PENDING' },
    );
    expect(objects.putKyc).toHaveBeenCalledTimes(3);
    const query = prisma.$executeRaw.mock.calls[0];
    expect(query).toEqual(
      expect.arrayContaining(['private/1', 'private/2', 'private/3']),
    );
  });

  it('removes uploaded evidence if saving the submission fails', async () => {
    prisma.$executeRaw.mockRejectedValueOnce(new Error('database unavailable'));
    await expect(service.submit('customer', submission)).rejects.toThrow(
      'database unavailable',
    );
    expect(objects.remove.mock.calls.map(([key]) => key)).toEqual([
      'private/1',
      'private/2',
      'private/3',
    ]);
  });
  it('does not publish private storage keys in review lists', async () => {
    prisma.$queryRaw.mockResolvedValue([
      {
        id: 's',
        filePath: 'private/front',
        backFilePath: null,
        selfieFilePath: 'private/selfie',
        signatureFilePath: 'private/signature',
      },
    ]);
    const [row] = await service.pendingForBusiness('owner');
    expect(row).toMatchObject({ hasSelfie: true, hasSignature: true });
    expect(JSON.stringify(row)).not.toContain('private/');
  });

  it('requires the assigned reviewer when loading selfie evidence', async () => {
    prisma.$queryRaw.mockResolvedValue([]);
    await expect(
      service.fileForBusiness('other-reviewer', 's', 'selfie'),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.$queryRaw.mock.calls[0]).toEqual(
      expect.arrayContaining(['s', 'other-reviewer']),
    );
    expect(objects.get).not.toHaveBeenCalled();
  });

  it('returns private signature content only through the protected file API', async () => {
    prisma.$queryRaw.mockResolvedValue([
      { signatureFilePath: 'private/signature' },
    ]);
    objects.get.mockResolvedValue(Buffer.from(png, 'base64'));
    await expect(
      service.fileForBusiness('owner', 's', 'signature'),
    ).resolves.toEqual({
      fileName: 'signature.png',
      mimeType: 'image/png',
      contentBase64: png,
    });
  });

  it('handles historical submissions without selfie evidence', async () => {
    prisma.$queryRaw.mockResolvedValue([
      { selfieFilePath: null, selfieMimeType: null },
    ]);
    await expect(
      service.fileForBusiness('owner', 's', 'selfie'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
