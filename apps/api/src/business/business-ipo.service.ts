import { NotFoundException } from '@nestjs/common';

import { AuditService } from '../audit/audit.service';
import { IpoService } from '../ipo/ipo.service';
import { PrismaService } from '../prisma/prisma.service';

export class BusinessIpoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ipoService: IpoService,
    private readonly auditService: AuditService,
  ) {}

  async myIpoApplications(businessUserId: string) {
    const applications = await this.prisma.ipoApplication.findMany({
      where: {
        account: {
          user: {
            assignedBusinessId: businessUserId,
          },
        },
      },
      include: {
        ipo: true,
        ipoDebt: true,
        account: {
          select: {
            accountNumber: true,
            cashBalance: true,
            user: {
              select: {
                id: true,
                customerNo: true,
                fullName: true,
                phone: true,
                status: true,
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    const reservedRows =
      applications.length === 0
        ? []
        : await this.prisma.ipoApplication.groupBy({
            by: ['ipoId'],
            where: {
              ipoId: { in: [...new Set(applications.map((row) => row.ipoId))] },
              status: 'PENDING',
              publishedAt: null,
              draftQuantity: { not: null },
            },
            _sum: { draftQuantity: true },
          });
    const reservedByIpo = new Map(
      reservedRows.map((row) => [row.ipoId, row._sum.draftQuantity ?? 0]),
    );

    return applications.map((application) => {
      const totalReserved = reservedByIpo.get(application.ipoId) ?? 0;
      const ownDraft =
        application.status === 'PENDING' &&
        application.publishedAt == null &&
        application.draftQuantity != null
          ? application.draftQuantity
          : 0;
      const reservedByOthers = Math.max(0, totalReserved - ownDraft);
      const remainingShares = IpoService.remainingAfterDrafts(
        application.ipo.availableShares,
        reservedByOthers,
      );
      return {
        id: application.id,
        quantity: application.quantity,
        amount: application.amount.toFixed(2),
        status: application.status,
        paymentStatus: application.paymentStatus,
        allocatedQuantity: application.allocatedQuantity,
        draftQuantity: application.draftQuantity,
        draftPrice: application.draftPrice?.toFixed(2) ?? null,
        publishedAt: application.publishedAt,
        allocatedPrice: application.allocatedPrice?.toFixed(2) ?? null,
        allocatedAmount: application.allocatedAmount?.toFixed(2) ?? null,
        createdAt: application.createdAt,
        ipo: {
          id: application.ipo.id,
          symbol: application.ipo.symbol,
          companyName: application.ipo.companyName,
          issuePrice: application.ipo.issuePrice.toFixed(2),
          totalShares: application.ipo.totalShares,
          availableShares: application.ipo.availableShares,
          reservedDraftShares: reservedByOthers,
          remainingShares,
          status: application.ipo.status,
        },
        account: {
          ...application.account,
          cashBalance: application.account.cashBalance.toFixed(2),
        },
        debt: application.ipoDebt
          ? {
              amount: application.ipoDebt.amount.toFixed(2),
              paidAmount: application.ipoDebt.paidAmount.toFixed(2),
              status: application.ipoDebt.status,
            }
          : null,
      };
    });
  }

  async allocateMyIpoApplication(
    businessUserId: string,
    applicationId: string,
    quantity: number,
    price: number | string,
  ) {
    const ownedApplication = await this.prisma.ipoApplication.findFirst({
      where: {
        id: applicationId,
        account: { user: { assignedBusinessId: businessUserId } },
      },
      select: { id: true },
    });
    if (!ownedApplication) {
      throw new NotFoundException(
        'IPO application is not assigned to this operator',
      );
    }
    const result = await this.ipoService.allocate(
      applicationId,
      quantity,
      price,
      businessUserId,
    );

    await this.auditService.createLog({
      actorId: businessUserId,
      action: 'BUSINESS_IPO_ALLOCATE',
      resource: 'ipo_application',
      resourceId: applicationId,
      description: `业务员分配 IPO 申请`,
      metadata: { quantity, price, debtAmount: result.debtAmount },
    });

    return result;
  }

  async publishMyIpoApplications(businessUserId: string, ids: string[]) {
    return this.ipoService.publish(ids, businessUserId, businessUserId);
  }
}
