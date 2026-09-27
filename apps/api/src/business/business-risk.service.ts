import { NotFoundException } from '@nestjs/common';

import { UserRole } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

export class BusinessRiskService {
  constructor(private readonly prisma: PrismaService) {}

  async customerLastLogin(businessUserId: string, customerId: string) {
    const customer = await this.prisma.user.findFirst({
      where: {
        id: customerId,
        role: UserRole.CLIENT,
        assignedBusinessId: businessUserId,
      },
      select: {
        id: true,
        fullName: true,
      },
    });

    if (!customer) {
      throw new NotFoundException('客户不存在');
    }

    const login = await this.prisma.loginAudit.findFirst({
      where: {
        userId: customerId,
        success: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return {
      customer,
      lastLogin: login,
    };
  }

  async customerLoginAudits(businessUserId: string, customerId: string) {
    const customer = await this.prisma.user.findFirst({
      where: {
        id: customerId,
        role: UserRole.CLIENT,
        assignedBusinessId: businessUserId,
      },
      select: {
        id: true,
        fullName: true,
      },
    });

    if (!customer) {
      throw new NotFoundException('客户不存在');
    }

    return this.prisma.loginAudit.findMany({
      where: {
        userId: customerId,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 100,
    });
  }

  async customerLoginRisk(businessUserId: string, customerId: string) {
    const customer = await this.prisma.user.findFirst({
      where: {
        id: customerId,
        role: UserRole.CLIENT,
        assignedBusinessId: businessUserId,
      },
      select: {
        id: true,
        fullName: true,
      },
    });

    if (!customer) {
      throw new NotFoundException('客户不存在');
    }

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const [failedCount, lastFailed, lastSuccess] =
      await this.prisma.$transaction([
        this.prisma.loginAudit.count({
          where: {
            userId: customerId,
            success: false,
            createdAt: {
              gte: since,
            },
          },
        }),

        this.prisma.loginAudit.findFirst({
          where: {
            userId: customerId,
            success: false,
          },
          orderBy: {
            createdAt: 'desc',
          },
        }),

        this.prisma.loginAudit.findFirst({
          where: {
            userId: customerId,
            success: true,
          },
          orderBy: {
            createdAt: 'desc',
          },
        }),
      ]);

    let riskLevel: 'LOW' | 'MEDIUM' | 'HIGH' = 'LOW';

    if (failedCount >= 10) {
      riskLevel = 'HIGH';
    } else if (failedCount >= 5) {
      riskLevel = 'MEDIUM';
    }

    return {
      customer,
      failedLoginCount24h: failedCount,
      riskLevel,
      lastFailedLogin: lastFailed,
      lastSuccessfulLogin: lastSuccess,
    };
  }

  async sharedIpRisks(businessUserId: string) {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const audits = await this.prisma.loginAudit.findMany({
      where: {
        success: true,
        createdAt: {
          gte: since,
        },
        ipAddress: {
          not: null,
        },
        user: {
          role: UserRole.CLIENT,
          assignedBusinessId: businessUserId,
        },
      },

      select: {
        ipAddress: true,
        createdAt: true,

        user: {
          select: {
            id: true,
            fullName: true,
            phone: true,
          },
        },
      },

      orderBy: {
        createdAt: 'desc',
      },
    });

    const ipMap = new Map<
      string,
      {
        ipAddress: string;
        customers: Map<
          string,
          {
            id: string;
            fullName: string;
            phone: string | null;
            lastLoginAt: Date;
          }
        >;
      }
    >();

    for (const audit of audits) {
      if (!audit.ipAddress) {
        continue;
      }

      let entry = ipMap.get(audit.ipAddress);

      if (!entry) {
        entry = {
          ipAddress: audit.ipAddress,
          customers: new Map(),
        };

        ipMap.set(audit.ipAddress, entry);
      }

      const existing = entry.customers.get(audit.user.id);

      if (!existing || audit.createdAt > existing.lastLoginAt) {
        entry.customers.set(audit.user.id, {
          id: audit.user.id,
          fullName: audit.user.fullName,
          phone: audit.user.phone,
          lastLoginAt: audit.createdAt,
        });
      }
    }

    return Array.from(ipMap.values())
      .map((item) => ({
        ipAddress: item.ipAddress,
        customerCount: item.customers.size,
        customers: Array.from(item.customers.values()),
      }))
      .filter((item) => item.customerCount >= 2)
      .sort((a, b) => b.customerCount - a.customerCount);
  }

  async myRiskDashboard(businessUserId: string) {
    const [
      sharedIpRisks,
      sharedDeviceRisks,
      failedLogin24h,
      highRiskCustomers,
    ] = await Promise.all([
      this.sharedIpRisks(businessUserId),

      this.sharedDeviceRisks(businessUserId),

      this.prisma.loginAudit.count({
        where: {
          success: false,

          createdAt: {
            gte: new Date(Date.now() - 24 * 60 * 60 * 1000),
          },

          user: {
            assignedBusinessId: businessUserId,
          },
        },
      }),

      this.prisma.user.count({
        where: {
          role: UserRole.CLIENT,

          assignedBusinessId: businessUserId,

          loginAudits: {
            some: {
              success: false,

              createdAt: {
                gte: new Date(Date.now() - 24 * 60 * 60 * 1000),
              },
            },
          },
        },
      }),
    ]);

    return {
      sharedIpCustomers: new Set(
        sharedIpRisks.flatMap((item) =>
          item.customers.map((customer) => customer.id),
        ),
      ).size,

      sharedDeviceCustomers: new Set(
        sharedDeviceRisks.flatMap((item) =>
          item.customers.map((customer) => customer.id),
        ),
      ).size,

      failedLogin24h,

      highRiskCustomers,
    };
  }

  async sharedDeviceRisks(businessUserId: string) {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const audits = await this.prisma.loginAudit.findMany({
      where: {
        success: true,

        createdAt: {
          gte: since,
        },

        userAgent: {
          not: null,
        },

        user: {
          role: UserRole.CLIENT,
          assignedBusinessId: businessUserId,
        },
      },

      select: {
        userAgent: true,
        createdAt: true,

        user: {
          select: {
            id: true,
            fullName: true,
            phone: true,
          },
        },
      },

      orderBy: {
        createdAt: 'desc',
      },
    });

    const deviceMap = new Map<
      string,
      Map<
        string,
        {
          id: string;
          fullName: string;
          phone: string;
          lastLoginAt: Date;
        }
      >
    >();

    for (const audit of audits) {
      if (!audit.userAgent) {
        continue;
      }

      if (!deviceMap.has(audit.userAgent)) {
        deviceMap.set(audit.userAgent, new Map());
      }

      const customers = deviceMap.get(audit.userAgent)!;

      const old = customers.get(audit.user.id);

      if (!old || audit.createdAt > old.lastLoginAt) {
        customers.set(audit.user.id, {
          id: audit.user.id,
          fullName: audit.user.fullName,
          phone: audit.user.phone ?? '',
          lastLoginAt: audit.createdAt,
        });
      }
    }

    return Array.from(deviceMap.entries())
      .map(([userAgent, customers]) => ({
        userAgent,
        customerCount: customers.size,
        customers: Array.from(customers.values()),
      }))
      .filter((item) => item.customerCount >= 2)
      .sort((a, b) => b.customerCount - a.customerCount);
  }
}
