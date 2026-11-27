import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { optionalIdempotencyKey } from '../common/idempotency-key';

export async function applyIpo(
  prisma: PrismaService,
  userId: string,
  ipoId: string,
  inputKey?: string,
) {
  const requestId = optionalIdempotencyKey(inputKey);
  if (!requestId)
    throw new BadRequestException(
      'Idempotency-Key is required for IPO applications',
    );
  return prisma.$transaction(async (tx) => {
    const account = await tx.account.findUnique({
      where: { userId },
      select: { id: true, accountNumber: true },
    });
    if (!account) throw new NotFoundException('Trading account not found');
    // All application creation enters here. No account funds are frozen at application time.
    const lockKey = `ipo-apply:${account.id}:${ipoId}`;
    await tx.$queryRaw`SELECT true AS locked FROM pg_advisory_xact_lock(hashtextextended(${lockKey}, 0))`;
    const previous = await tx.ipoApplication.findUnique({
      where: {
        accountId_ipoId_requestId: { accountId: account.id, ipoId, requestId },
      },
    });
    if (previous?.response) return previous.response;
    const ipo = await tx.ipo.findUnique({ where: { id: ipoId } });
    if (!ipo) throw new NotFoundException('IPO not found');
    if (!['PUBLISHED', 'OPEN'].includes(ipo.status))
      throw new BadRequestException('IPO is not published for applications');
    const now = new Date();
    if (now < ipo.openDate || now > ipo.closeDate)
      throw new BadRequestException('IPO application period is not active');
    // Existing policy counts every status, including historical excess; never rewrite history.
    const appliedCount = await tx.ipoApplication.count({
      where: { accountId: account.id, ipoId },
    });
    if (appliedCount >= 5)
      return {
        message: 'Maximum IPO applications reached',
        canApply: false,
        appliedCount,
        maxApplyCount: 5,
      };
    const application = await tx.ipoApplication.create({
      data: {
        accountId: account.id,
        ipoId,
        requestId,
        quantity: 1,
        amount: ipo.issuePrice,
        status: 'PENDING',
        paymentStatus: 'PENDING',
      },
    });
    const response = {
      message: 'IPO application submitted successfully',
      canApply: true,
      appliedCount: appliedCount + 1,
      maxApplyCount: 5,
      application: {
        id: application.id,
        status: application.status,
        paymentStatus: application.paymentStatus,
        createdAt: application.createdAt.toISOString(),
        accountNumber: account.accountNumber,
        ipo: {
          id: ipo.id,
          symbol: ipo.symbol,
          companyName: ipo.companyName,
          exchange: ipo.exchange,
          issuePrice: ipo.issuePrice.toFixed(2),
        },
      },
    };
    await tx.ipoApplication.update({
      where: { id: application.id },
      data: { response: response },
    });
    return response;
  });
}
