import { Injectable, NotFoundException } from '@nestjs/common';

import { UserRole } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async customers() {
    return this.prisma.user.findMany({
      where: {
        role: UserRole.CLIENT,
      },
      select: {
        id: true,
        customerNo: true,
        fullName: true,
        phone: true,
        role: true,
        status: true,
        createdAt: true,
        updatedAt: true,

        account: {
          select: {
            id: true,
            accountNumber: true,
            cashBalance: true,
            buyingPower: true,
            frozenBalance: true,
            currency: true,
            isLive: true,
            createdAt: true,
            updatedAt: true,
          },
        },

        assignedBusiness: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            businessProfile: {
              select: {
                employeeNo: true,
                department: true,
              },
            },
          },
        },

        loginAudits: {
          take: 1,
          where: {
            success: true,
          },
          orderBy: {
            createdAt: 'desc',
          },
          select: {
            ipAddress: true,
            userAgent: true,
            success: true,
            createdAt: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async customerLastLogin(customerId: string) {
    const customer = await this.prisma.user.findFirst({
      where: {
        id: customerId,
        role: UserRole.CLIENT,
      },
      select: {
        id: true,
        fullName: true,
        phone: true,
      },
    });

    if (!customer) {
      throw new NotFoundException('未找到客户');
    }

    const lastLogin = await this.prisma.loginAudit.findFirst({
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
      lastLogin,
    };
  }

  async customerLoginAudits(customerId: string) {
    const customer = await this.prisma.user.findFirst({
      where: {
        id: customerId,
        role: UserRole.CLIENT,
      },
      select: {
        id: true,
      },
    });

    if (!customer) {
      throw new NotFoundException('未找到客户');
    }

    return this.prisma.loginAudit.findMany({
      where: {
        userId: customerId,
      },
      select: {
        id: true,
        ipAddress: true,
        userAgent: true,
        success: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 100,
    });
  }

  async customerLoginRisk(customerId: string) {
    const customer = await this.prisma.user.findFirst({
      where: {
        id: customerId,
        role: UserRole.CLIENT,
      },
      select: {
        id: true,
        fullName: true,
      },
    });

    if (!customer) {
      throw new NotFoundException('未找到客户');
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

  async loginRiskSummary() {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const clients = await this.prisma.user.findMany({
      where: {
        role: UserRole.CLIENT,
      },
      select: {
        id: true,
        fullName: true,
        phone: true,

        assignedBusiness: {
          select: {
            id: true,
            fullName: true,
            businessProfile: {
              select: {
                employeeNo: true,
              },
            },
          },
        },
      },
    });

    const failedGroups = await this.prisma.loginAudit.groupBy({
      by: ['userId'],
      where: {
        success: false,
        createdAt: {
          gte: since,
        },
      },
      _count: {
        _all: true,
      },
    });

    const failedCountMap = new Map(
      failedGroups.map((item) => [item.userId, item._count._all]),
    );

    let highRiskCustomers = 0;
    let mediumRiskCustomers = 0;

    const customerRisks = clients.map((client) => {
      const failedLoginCount24h = failedCountMap.get(client.id) ?? 0;

      let riskLevel: 'LOW' | 'MEDIUM' | 'HIGH' = 'LOW';

      if (failedLoginCount24h >= 10) {
        riskLevel = 'HIGH';
        highRiskCustomers += 1;
      } else if (failedLoginCount24h >= 5) {
        riskLevel = 'MEDIUM';
        mediumRiskCustomers += 1;
      }

      return {
        customerId: client.id,
        fullName: client.fullName,
        phone: client.phone,
        failedLoginCount24h,
        riskLevel,
        assignedBusiness: client.assignedBusiness,
      };
    });

    const failedLoginCount24h = failedGroups.reduce(
      (sum, item) => sum + item._count._all,
      0,
    );

    const recentFailedLogins = await this.prisma.loginAudit.findMany({
      where: {
        success: false,
      },
      select: {
        id: true,
        ipAddress: true,
        userAgent: true,
        createdAt: true,

        user: {
          select: {
            id: true,
            fullName: true,
            phone: true,

            assignedBusiness: {
              select: {
                id: true,
                fullName: true,

                businessProfile: {
                  select: {
                    employeeNo: true,
                  },
                },
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 20,
    });

    return {
      failedLoginCount24h,
      highRiskCustomers,
      mediumRiskCustomers,
      totalCustomers: clients.length,

      customerRisks: customerRisks
        .filter(
          (item) => item.riskLevel === 'HIGH' || item.riskLevel === 'MEDIUM',
        )
        .sort((a, b) => b.failedLoginCount24h - a.failedLoginCount24h),

      recentFailedLogins,
    };
  }

  async sharedIpRisks() {
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

            assignedBusiness: {
              select: {
                id: true,
                fullName: true,

                businessProfile: {
                  select: {
                    employeeNo: true,
                  },
                },
              },
            },
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
            assignedBusiness: {
              id: string;
              fullName: string;
              businessProfile: {
                employeeNo: string;
              } | null;
            } | null;
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

      const existingCustomer = entry.customers.get(audit.user.id);

      if (!existingCustomer || audit.createdAt > existingCustomer.lastLoginAt) {
        entry.customers.set(audit.user.id, {
          id: audit.user.id,
          fullName: audit.user.fullName,
          phone: audit.user.phone,
          assignedBusiness: audit.user.assignedBusiness,
          lastLoginAt: audit.createdAt,
        });
      }
    }

    return Array.from(ipMap.values())
      .map((entry) => ({
        ipAddress: entry.ipAddress,
        customerCount: entry.customers.size,
        customers: Array.from(entry.customers.values()),
      }))
      .filter((entry) => entry.customerCount >= 2)
      .sort((a, b) => b.customerCount - a.customerCount);
  }

  async sharedDeviceRisks() {
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

            assignedBusiness: {
              select: {
                id: true,
                fullName: true,

                businessProfile: {
                  select: {
                    employeeNo: true,
                  },
                },
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    const deviceMap = new Map<
      string,
      {
        userAgent: string;
        customers: Map<
          string,
          {
            id: string;
            fullName: string;
            phone: string | null;
            assignedBusiness: {
              id: string;
              fullName: string;
              businessProfile: {
                employeeNo: string;
              } | null;
            } | null;
            lastLoginAt: Date;
          }
        >;
      }
    >();

    for (const audit of audits) {
      if (!audit.userAgent) {
        continue;
      }

      let entry = deviceMap.get(audit.userAgent);

      if (!entry) {
        entry = {
          userAgent: audit.userAgent,
          customers: new Map(),
        };

        deviceMap.set(audit.userAgent, entry);
      }

      const existingCustomer = entry.customers.get(audit.user.id);

      if (!existingCustomer || audit.createdAt > existingCustomer.lastLoginAt) {
        entry.customers.set(audit.user.id, {
          id: audit.user.id,
          fullName: audit.user.fullName,
          phone: audit.user.phone,
          assignedBusiness: audit.user.assignedBusiness,
          lastLoginAt: audit.createdAt,
        });
      }
    }

    return Array.from(deviceMap.values())
      .map((entry) => ({
        userAgent: entry.userAgent,
        customerCount: entry.customers.size,
        customers: Array.from(entry.customers.values()),
      }))
      .filter((entry) => entry.customerCount >= 2)
      .sort((a, b) => b.customerCount - a.customerCount);
  }
}
