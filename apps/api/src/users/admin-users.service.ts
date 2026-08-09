import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ListAdminUsersQueryDto } from './dto/list-admin-users-query.dto';
import { UpdateUserRoleDto } from './dto/update-user-role.dto';
import { UpdateUserStatusDto } from './dto/update-user-status.dto';
import { AuditService } from '../audit/audit.service';
@Injectable()
export class AdminUsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}
  async listUsers(query: ListAdminUsersQueryDto) {
    const search = query.search?.trim();
    const skip = (query.page - 1) * query.pageSize;

    const where: Prisma.UserWhereInput = {
      ...(query.role ? { role: query.role } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(search
        ? {
            OR: [
              {
                fullName: {
                  contains: search,
                  mode: 'insensitive',
                },
              },
              {
                phone: {
                  contains: search,
                  mode: 'insensitive',
                },
              },
              {
                account: {
                  accountNumber: {
                    contains: search,
                    mode: 'insensitive',
                  },
                },
              },
            ],
          }
        : {}),
    };

    const [total, users] = await this.prisma.$transaction([
      this.prisma.user.count({
        where,
      }),
      this.prisma.user.findMany({
        where,
        include: {
          account: {
            select: {
              id: true,
              accountNumber: true,
              currency: true,
              isLive: true,
              cashBalance: true,
              buyingPower: true,
              frozenBalance: true,
              createdAt: true,
              updatedAt: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: query.pageSize,
      }),
    ]);

    return {
      page: query.page,
      pageSize: query.pageSize,
      total,
      totalPages: Math.ceil(total / query.pageSize),
      filters: {
        search: search ?? null,
        role: query.role ?? null,
        status: query.status ?? null,
      },
      data: users.map((user) => ({
        id: user.id,
        fullName: user.fullName,
        phone: user.phone,
        role: user.role,
        status: user.status,
        account: user.account
          ? {
              id: user.account.id,
              accountNumber: user.account.accountNumber,
              currency: user.account.currency,
              isLive: user.account.isLive,
              balances: {
                cashBalance: user.account.cashBalance.toFixed(2),
                buyingPower: user.account.buyingPower.toFixed(2),
                frozenBalance: user.account.frozenBalance.toFixed(2),
              },
              createdAt: user.account.createdAt,
              updatedAt: user.account.updatedAt,
            }
          : null,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      })),
    };
  }

  async getUser(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: {
        id: userId,
      },
      include: {
        account: {
          include: {
            positions: {
              where: {
                quantity: {
                  gt: 0,
                },
              },
              include: {
                instrument: {
                  include: {
                    quote: true,
                  },
                },
              },
              orderBy: {
                updatedAt: 'desc',
              },
            },
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    let holdingsMarketValue = new Prisma.Decimal(0);

    const positions =
      user.account?.positions.map((position) => {
        const lastPrice =
          position.instrument.quote?.lastPrice ?? new Prisma.Decimal(0);

        const marketValue = lastPrice.mul(position.quantity).toDecimalPlaces(2);

        const unrealizedPnl = lastPrice
          .sub(position.averagePrice)
          .mul(position.quantity)
          .toDecimalPlaces(2);

        holdingsMarketValue = holdingsMarketValue.add(marketValue);

        return {
          id: position.id,
          exchange: position.instrument.exchange,
          symbol: position.instrument.symbol,
          name: position.instrument.name,
          quantity: position.quantity,
          frozenQuantity: position.frozenQuantity,
          availableQuantity: position.quantity - position.frozenQuantity,
          averagePrice: position.averagePrice.toFixed(4),
          lastPrice: lastPrice.toFixed(4),
          marketValue: marketValue.toFixed(2),
          realizedPnl: position.realizedPnl.toFixed(2),
          unrealizedPnl: unrealizedPnl.toFixed(2),
          updatedAt: position.updatedAt,
        };
      }) ?? [];

    const totalAsset = user.account
      ? user.account.cashBalance.add(holdingsMarketValue).toDecimalPlaces(2)
      : new Prisma.Decimal(0);

    return {
      id: user.id,
      fullName: user.fullName,
      phone: user.phone,
      role: user.role,
      status: user.status,
      account: user.account
        ? {
            id: user.account.id,
            accountNumber: user.account.accountNumber,
            currency: user.account.currency,
            isLive: user.account.isLive,
            balances: {
              cashBalance: user.account.cashBalance.toFixed(2),
              buyingPower: user.account.buyingPower.toFixed(2),
              frozenBalance: user.account.frozenBalance.toFixed(2),
              holdingsMarketValue: holdingsMarketValue.toFixed(2),
              totalAsset: totalAsset.toFixed(2),
            },
            positionCount: positions.length,
            positions,
            createdAt: user.account.createdAt,
            updatedAt: user.account.updatedAt,
          }
        : null,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }

  async updateStatus(
    administratorId: string,
    userId: string,
    dto: UpdateUserStatusDto,
  ) {
    if (administratorId === userId && dto.status !== 'ACTIVE') {
      throw new BadRequestException(
        'You cannot suspend or disable your own account',
      );
    }

    const user = await this.prisma.user.findUnique({
      where: {
        id: userId,
      },
      select: {
        id: true,
        status: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const updatedUser = await this.prisma.user.update({
      where: {
        id: userId,
      },
      data: {
        status: dto.status,
      },
      select: {
        id: true,
        fullName: true,
        phone: true,
        role: true,
        status: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    await this.auditService.createLog({
      actorId: administratorId,
      action: 'USER_STATUS_UPDATED',
      resource: 'USER',
      resourceId: userId,
      description: `User status changed from ${user.status} to ${updatedUser.status}`,
      metadata: {
        previousStatus: user.status,
        newStatus: updatedUser.status,
        targetPhone: updatedUser.phone,
      },
    });

    return {
      message: 'User status updated successfully',
      previousStatus: user.status,
      user: updatedUser,
    };
  }

  async updateRole(
    administratorId: string,
    userId: string,
    dto: UpdateUserRoleDto,
  ) {
    if (administratorId === userId && dto.role !== 'ADMIN') {
      throw new BadRequestException(
        'You cannot remove your own administrator role',
      );
    }

    const user = await this.prisma.user.findUnique({
      where: {
        id: userId,
      },
      select: {
        id: true,
        role: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const updatedUser = await this.prisma.user.update({
      where: {
        id: userId,
      },
      data: {
        role: dto.role,
      },
      select: {
        id: true,
        fullName: true,
        phone: true,
        role: true,
        status: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    await this.auditService.createLog({
      actorId: administratorId,
      action: 'USER_ROLE_UPDATED',
      resource: 'USER',
      resourceId: userId,
      description: `User role changed from ${user.role} to ${updatedUser.role}`,
      metadata: {
        previousRole: user.role,
        newRole: updatedUser.role,
        targetPhone: updatedUser.phone,
      },
    });

    return {
      message: 'User role updated successfully',
      previousRole: user.role,
      user: updatedUser,
    };
  }
}
