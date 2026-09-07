import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { extname } from 'path';

import { PrismaService } from '../prisma/prisma.service';
import { PrivateObjectStorageService } from '../storage/private-object-storage.service';

export type KycSubmissionInput = {
  fullName?: string;
  bankDetails?: { accountHolder: string; bankName: string; accountNumber: string; ifscCode: string };
  documentType: 'AADHAAR' | 'PAN';
  fileName: string;
  mimeType?: string;
  contentBase64: string;
  backFileName?: string;
  backMimeType?: string;
  backContentBase64?: string;
  selfieContentBase64: string;
  selfieMimeType: string;
  signatureContentBase64: string;
};

type KycEvidenceRow = {
  selfieFilePath: string | null;
  selfieMimeType: string | null;
  signatureFilePath: string | null;
};

type KycSubmissionRow = KycEvidenceRow & {
  id: string;
  documentType: string;
  status: string;
  fileName: string;
  filePath: string;
  mimeType: string | null;
  backFileName: string | null;
  backFilePath: string | null;
  backMimeType: string | null;
  recognizedType: string | null;
  recognizedText: string | null;
  reviewNote: string | null;
  createdAt: Date;
  userId: string;
  fullName: string;
  phone: string | null;
  bankDetails?: KycSubmissionInput['bankDetails'];
};

type KycFileRow = KycEvidenceRow & {
  fileName: string;
  filePath: string;
  mimeType: string | null;
  backFileName: string | null;
  backFilePath: string | null;
  backMimeType: string | null;
};

@Injectable()
export class KycService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly objects: PrivateObjectStorageService,
  ) {}

  async submit(userId: string, input: KycSubmissionInput) {
    const fullName = typeof input.fullName === 'string' ? input.fullName.trim() : '';
    const bank = input.bankDetails;
    if (fullName.length < 2 || fullName.length > 120 || !bank ||
        typeof bank.accountHolder !== 'string' || typeof bank.bankName !== 'string' ||
        typeof bank.accountNumber !== 'string' || typeof bank.ifscCode !== 'string' ||
        bank.bankName.trim().length < 2 || bank.bankName.length > 120 ||
        !/^\d{6,18}$/.test(bank.accountNumber) ||
        (bank.ifscCode !== '' && !/^[A-Z]{4}0[A-Z0-9]{6}$/.test(bank.ifscCode)) ||
        bank.accountHolder.trim().toLocaleLowerCase('en-IN') !== fullName.toLocaleLowerCase('en-IN')) {
      throw new BadRequestException('Enter valid personal and bank details. The account holder must match your identity name.');
    }
    if (input.documentType !== 'AADHAAR' && input.documentType !== 'PAN') {
      throw new BadRequestException('Unsupported KYC document type');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        assignedBusinessId: true,
      },
    });

    if (!user || !user.assignedBusinessId) {
      throw new NotFoundException('Registered customer not found');
    }

    const fileBuffer = this.decodeBase64(input.contentBase64, 'KYC front file');

    if (fileBuffer.length === 0) {
      throw new BadRequestException('KYC file is empty');
    }

    if (fileBuffer.length > 8 * 1024 * 1024) {
      throw new BadRequestException('KYC file must be 8 MB or smaller');
    }

    const backBuffer = input.backContentBase64
      ? this.decodeBase64(input.backContentBase64, 'KYC back file')
      : null;
    if (
      input.documentType === 'AADHAAR' &&
      (!backBuffer || !input.backFileName)
    ) {
      throw new BadRequestException(
        'Aadhaar front and back files are required',
      );
    }
    if (
      backBuffer &&
      (backBuffer.length === 0 || backBuffer.length > 8 * 1024 * 1024)
    ) {
      throw new BadRequestException('Each KYC file must be 8 MB or smaller');
    }

    if (typeof input.fileName !== 'string' || !input.fileName.trim()) {
      throw new BadRequestException('KYC file name is required');
    }
    const selfie = this.decodeBase64(input.selfieContentBase64, 'Selfie');
    const signature = this.decodeBase64(
      input.signatureContentBase64,
      'Signature',
    );
    if (selfie.length > 2 * 1024 * 1024) {
      throw new BadRequestException('Selfie must be 2 MB or smaller');
    }
    if (signature.length > 1024 * 1024) {
      throw new BadRequestException('Signature must be 1 MB or smaller');
    }
    if (
      !['image/jpeg', 'image/png', 'image/webp'].includes(input.selfieMimeType)
    ) {
      throw new BadRequestException('Selfie must be a JPG, PNG or WebP image');
    }

    const storedKeys: string[] = [];
    const store = async (bytes: Buffer, mime?: string) => {
      const object = await this.objects.putKyc(user.id, bytes, mime);
      storedKeys.push(object.key);
      return object;
    };
    try {
      // putKyc verifies the actual file signature and applies the configured
      // malware scanner. Evidence remains in the same private storage as IDs.
      const selfieObject = await store(selfie, input.selfieMimeType);
      const signatureObject = await store(signature, 'image/png');
      const frontObject = await store(fileBuffer, input.mimeType);
      const filePath = frontObject.key;

      let backFilePath: string | null = null;
      if (backBuffer && input.backFileName) {
        backFilePath = (await store(backBuffer, input.backMimeType)).key;
      }

      const recognizedType = this.recognizeDocumentType(
        input.fileName,
        input.documentType,
      );

      await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM users WHERE id = ${user.id} FOR UPDATE`;
      const existing = await tx.$queryRaw<{ id: string }[]>`SELECT id FROM kyc_submissions WHERE "userId" = ${user.id} AND status IN ('PENDING', 'APPROVED') LIMIT 1`;
      if (existing.length) throw new BadRequestException('KYC is already submitted or approved');
      await tx.$executeRaw`
      INSERT INTO "kyc_submissions"
        ("userId", "businessUserId", "documentType", "status", "fileName", "filePath", "mimeType", "backFileName", "backFilePath", "backMimeType", "recognizedType", "recognizedText", "selfieFilePath", "selfieMimeType", "signatureFilePath", "fullName", "bankDetails", "updatedAt")
      VALUES
        (${user.id}, ${user.assignedBusinessId}, ${input.documentType}, 'PENDING', ${input.fileName}, ${filePath}, ${frontObject.mime}, ${input.backFileName ?? null}, ${backFilePath}, ${input.backMimeType ?? null}, ${recognizedType}, ${`Selected document: ${recognizedType}`}, ${selfieObject.key}, ${selfieObject.mime}, ${signatureObject.key}, ${fullName}, ${JSON.stringify(bank)}::jsonb, CURRENT_TIMESTAMP)
    `;
      });

      return {
        message: 'KYC submitted for review',
        status: 'PENDING',
        recognizedType,
      };
    } catch (error) {
      // A rejected upload or failed database insert must not leave new identity
      // evidence behind without a submission that owns it.
      await Promise.allSettled(
        storedKeys.map((key) => this.objects.remove(key)),
      );
      throw error;
    }
  }
  private decodeBase64(value: string, label: string) {
    const normalized = typeof value === 'string' ? value.trim() : '';
    if (
      !normalized ||
      normalized.length > 11_200_000 ||
      normalized.length % 4 !== 0 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(normalized)
    ) {
      throw new BadRequestException(`${label} is not valid base64 data`);
    }
    const bytes = Buffer.from(normalized, 'base64');
    if (bytes.toString('base64') !== normalized) {
      throw new BadRequestException(`${label} is not valid base64 data`);
    }
    return bytes;
  }

  async pendingForBusiness(businessUserId: string) {
    const rows = await this.prisma.$queryRaw<KycSubmissionRow[]>`
      SELECT
        k."id",
        k."documentType",
        k."status",
        k."fileName",
        k."filePath",
        k."mimeType",
        k."backFileName",
        k."backFilePath",
        k."backMimeType",
        k."selfieFilePath",
        k."selfieMimeType",
        k."signatureFilePath",
        k."recognizedType",
        k."recognizedText",
        k."reviewNote",
        k."createdAt",
        u."id" AS "userId",
        COALESCE(k."fullName", u."fullName") AS "fullName",
        k."bankDetails",
        u."phone"
      FROM "kyc_submissions" k
      JOIN "users" u ON u."id" = k."userId"
      WHERE k."businessUserId" = ${businessUserId}
      ORDER BY k."createdAt" DESC
    `;

    return rows.map(
      ({
        filePath: _frontKey,
        backFilePath: _backKey,
        selfieFilePath,
        signatureFilePath,
        ...row
      }) => ({
        ...row,
        hasSelfie: Boolean(selfieFilePath),
        hasSignature: Boolean(signatureFilePath),
        frontFileEndpoint: `/kyc/business/${row.id}/file?side=front`,
        backFileEndpoint: row.backFileName
          ? `/kyc/business/${row.id}/file?side=back`
          : null,
      }),
    );
  }

  async fileForBusiness(
    businessUserId: string,
    submissionId: string,
    side: 'front' | 'back' | 'selfie' | 'signature',
  ) {
    const rows = await this.prisma.$queryRaw<KycFileRow[]>`
      SELECT "fileName", "filePath", "mimeType", "backFileName", "backFilePath", "backMimeType", "selfieFilePath", "selfieMimeType", "signatureFilePath"
      FROM "kyc_submissions"
      WHERE "id" = ${submissionId}
        AND "businessUserId" = ${businessUserId}
      LIMIT 1
    `;
    const file = rows[0];

    if (!file) {
      throw new NotFoundException('KYC file not found');
    }

    const isBack = side === 'back';
    const selectedPath =
      side === 'selfie'
        ? file.selfieFilePath
        : side === 'signature'
          ? file.signatureFilePath
          : isBack
            ? file.backFilePath
            : file.filePath;
    const selectedName =
      side === 'selfie'
        ? `selfie.${file.selfieMimeType === 'image/png' ? 'png' : file.selfieMimeType === 'image/webp' ? 'webp' : 'jpg'}`
        : side === 'signature'
          ? 'signature.png'
          : isBack
            ? file.backFileName
            : file.fileName;
    const selectedMime =
      side === 'selfie'
        ? file.selfieMimeType
        : side === 'signature'
          ? 'image/png'
          : isBack
            ? file.backMimeType
            : file.mimeType;
    if (!selectedPath || !selectedName) {
      throw new NotFoundException('KYC file side not found');
    }
    const content = await this.objects.get(selectedPath);

    return {
      fileName: selectedName,
      mimeType: selectedMime ?? this.mimeTypeForFile(selectedName),
      contentBase64: content.toString('base64'),
    };
  }

  async status(userId: string) {
    const rows = await this.prisma.$queryRaw<
      {
        status: string;
        documentType: string;
        recognizedType: string | null;
        createdAt: Date;
      }[]
    >`
      SELECT k."status", k."documentType", k."recognizedType", k."createdAt", k."reviewNote"
      FROM "kyc_submissions" k
      WHERE k."userId" = ${userId}
      ORDER BY k."createdAt" DESC
      LIMIT 1
    `;

    return rows[0] ?? { status: 'NOT_SUBMITTED' };
  }

  async review(
    businessUserId: string,
    input: {
      submissionId: string;
      decision: 'APPROVED' | 'REJECTED';
      note?: string;
    },
  ) {
    if (input.decision !== 'APPROVED' && input.decision !== 'REJECTED') {
      throw new BadRequestException('Invalid KYC review decision');
    }

    return this.prisma.$transaction(async tx => {
    const [submission] = await tx.$queryRaw<KycSubmissionRow[]>`SELECT * FROM kyc_submissions WHERE id = ${input.submissionId} AND "businessUserId" = ${businessUserId} AND status = 'PENDING' FOR UPDATE`;
    if (!submission) throw new NotFoundException('Pending KYC submission not found');
    const updated = await tx.$executeRaw`
      UPDATE "kyc_submissions"
      SET
        "status" = ${input.decision},
        "reviewNote" = ${input.note ?? null},
        "reviewedById" = ${businessUserId},
        "reviewedAt" = CURRENT_TIMESTAMP,
        "updatedAt" = CURRENT_TIMESTAMP
      WHERE "id" = ${input.submissionId}
        AND "businessUserId" = ${businessUserId}
        AND "status" = 'PENDING'
    `;

    if (Number(updated) !== 1) {
      throw new NotFoundException('Pending KYC submission not found');
    }

    if (input.decision === 'APPROVED') {
      await tx.$executeRaw`
        UPDATE "users" u
        SET "status" = 'ACTIVE', "fullName" = COALESCE(k."fullName", u."fullName"), "updatedAt" = CURRENT_TIMESTAMP
        FROM "kyc_submissions" k
        WHERE k."id" = ${input.submissionId}
          AND k."userId" = u."id"
          AND k."businessUserId" = ${businessUserId}
          AND u."status" != 'DISABLED'
      `;
      if (submission.bankDetails) {
        const bank = submission.bankDetails;
        const existingBank = await tx.bankAccount.findFirst({ where: { userId: submission.userId, accountNumber: bank.accountNumber, ifscCode: bank.ifscCode } });
        if (!existingBank) {
          const count = await tx.bankAccount.count({ where: { userId: submission.userId } });
          await tx.bankAccount.create({ data: { ...bank, userId: submission.userId, status: 'APPROVED', isPrimary: count === 0 } });
        }
      }
    }

    await tx.notification.create({ data: { userId: submission.userId, type: 'KYC', title: input.decision === 'APPROVED' ? 'KYC approved' : 'KYC requires an update', body: input.note?.trim() || (input.decision === 'APPROVED' ? 'Your identity verification is complete.' : 'Please review and resubmit your documents.') } });

    return {
      reviewed: true,
      status: input.decision,
    };
    });
  }

  private normalizeIndianPhone(value: string): string | null {
    const digits = value.replace(/\D/g, '');

    if (/^[6-9]\d{9}$/.test(digits)) {
      return digits;
    }

    if (/^91[6-9]\d{9}$/.test(digits)) {
      return digits.slice(2);
    }

    return null;
  }

  private recognizeDocumentType(
    fileName: string,
    selectedType: 'AADHAAR' | 'PAN',
  ) {
    const normalized = fileName.toLowerCase();

    if (normalized.includes('pan')) {
      return 'PAN';
    }

    if (
      normalized.includes('aadhaar') ||
      normalized.includes('aadhar') ||
      normalized.includes('uid')
    ) {
      return 'AADHAAR';
    }

    return selectedType;
  }

  private safeExtension(fileName: string) {
    const extension = extname(fileName).toLowerCase();
    const allowed = new Set(['.pdf', '.jpg', '.jpeg', '.png', '.webp']);

    return allowed.has(extension) ? extension : '.bin';
  }

  private mimeTypeForFile(fileName: string) {
    const extension = extname(fileName).toLowerCase();

    if (extension === '.pdf') return 'application/pdf';
    if (extension === '.jpg' || extension === '.jpeg') return 'image/jpeg';
    if (extension === '.png') return 'image/png';
    if (extension === '.webp') return 'image/webp';

    return 'application/octet-stream';
  }
}
