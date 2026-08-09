import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { mkdir, readFile, writeFile } from 'fs/promises';
import { extname, join } from 'path';

import { PrismaService } from '../prisma/prisma.service';

type KycSubmissionRow = {
  id: string;
  documentType: string;
  status: string;
  fileName: string;
  filePath: string;
  mimeType: string | null;
  recognizedType: string | null;
  recognizedText: string | null;
  reviewNote: string | null;
  createdAt: Date;
  userId: string;
  fullName: string;
  phone: string | null;
};

type KycFileRow = {
  fileName: string;
  filePath: string;
  mimeType: string | null;
};

@Injectable()
export class KycService {
  constructor(private readonly prisma: PrismaService) {}

  async submit(input: {
    phone: string;
    documentType: 'AADHAAR' | 'PAN';
    fileName: string;
    mimeType?: string;
    contentBase64: string;
  }) {
    const phone = this.normalizeIndianPhone(input.phone);

    if (!phone) {
      throw new BadRequestException('Invalid Indian mobile number');
    }

    if (input.documentType !== 'AADHAAR' && input.documentType !== 'PAN') {
      throw new BadRequestException('Unsupported KYC document type');
    }

    const user = await this.prisma.user.findFirst({
      where: {
        phone,
      },
      select: {
        id: true,
        assignedBusinessId: true,
      },
    });

    if (!user || !user.assignedBusinessId) {
      throw new NotFoundException('Registered customer not found');
    }

    const fileBuffer = Buffer.from(input.contentBase64, 'base64');

    if (fileBuffer.length === 0) {
      throw new BadRequestException('KYC file is empty');
    }

    if (fileBuffer.length > 8 * 1024 * 1024) {
      throw new BadRequestException('KYC file must be 8 MB or smaller');
    }

    const safeExtension = this.safeExtension(input.fileName);
    const storedFileName = `${user.id}-${Date.now()}-${randomUUID()}${safeExtension}`;
    const uploadDir = join(process.cwd(), 'uploads', 'kyc');
    const filePath = join(uploadDir, storedFileName);

    await mkdir(uploadDir, { recursive: true });
    await writeFile(filePath, fileBuffer);

    const recognizedType = this.recognizeDocumentType(
      input.fileName,
      input.documentType,
    );

    await this.prisma.$executeRaw`
      INSERT INTO "kyc_submissions"
        ("userId", "businessUserId", "documentType", "status", "fileName", "filePath", "mimeType", "recognizedType", "recognizedText", "updatedAt")
      VALUES
        (${user.id}, ${user.assignedBusinessId}, ${input.documentType}, 'PENDING', ${input.fileName}, ${filePath}, ${input.mimeType ?? null}, ${recognizedType}, ${`Auto detected as ${recognizedType}`}, CURRENT_TIMESTAMP)
    `;

    return {
      message: 'KYC submitted for review',
      status: 'PENDING',
      recognizedType,
    };
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
        k."recognizedType",
        k."recognizedText",
        k."reviewNote",
        k."createdAt",
        u."id" AS "userId",
        u."fullName",
        u."phone"
      FROM "kyc_submissions" k
      JOIN "users" u ON u."id" = k."userId"
      WHERE k."businessUserId" = ${businessUserId}
      ORDER BY k."createdAt" DESC
    `;

    return rows;
  }

  async fileForBusiness(businessUserId: string, submissionId: string) {
    const rows = await this.prisma.$queryRaw<KycFileRow[]>`
      SELECT "fileName", "filePath", "mimeType"
      FROM "kyc_submissions"
      WHERE "id" = ${submissionId}
        AND "businessUserId" = ${businessUserId}
      LIMIT 1
    `;
    const file = rows[0];

    if (!file) {
      throw new NotFoundException('KYC file not found');
    }

    const content = await readFile(file.filePath);

    return {
      fileName: file.fileName,
      mimeType: file.mimeType ?? this.mimeTypeForFile(file.fileName),
      contentBase64: content.toString('base64'),
    };
  }

  async status(phoneValue: string) {
    const phone = this.normalizeIndianPhone(phoneValue || '');

    if (!phone) {
      throw new BadRequestException('Invalid Indian mobile number');
    }

    const rows = await this.prisma.$queryRaw<
      { status: string; documentType: string; recognizedType: string | null; createdAt: Date }[]
    >`
      SELECT k."status", k."documentType", k."recognizedType", k."createdAt"
      FROM "kyc_submissions" k
      JOIN "users" u ON u."id" = k."userId"
      WHERE u."phone" = ${phone}
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

    const updated = await this.prisma.$executeRaw`
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
      await this.prisma.$executeRaw`
        UPDATE "users" u
        SET "status" = 'ACTIVE', "updatedAt" = CURRENT_TIMESTAMP
        FROM "kyc_submissions" k
        WHERE k."id" = ${input.submissionId}
          AND k."userId" = u."id"
          AND k."businessUserId" = ${businessUserId}
      `;
    }

    return {
      reviewed: true,
      status: input.decision,
    };
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

  private recognizeDocumentType(fileName: string, selectedType: 'AADHAAR' | 'PAN') {
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
