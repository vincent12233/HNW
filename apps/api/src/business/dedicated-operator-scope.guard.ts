import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';

import { UserRole } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DedicatedOperatorScopeGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<{ user?: { userId?: string; role?: UserRole } }>();
    if (request.user?.role !== UserRole.SUPPORT) return true;

    const userId = request.user.userId;
    const fixedCode = process.env.ADMIN_FIXED_INVITE_CODE?.trim().toUpperCase() || 'ADMINFIXED2026';
    if (!userId) throw new ForbiddenException('Dedicated operator identity is missing');

    const operator = await this.prisma.user.findFirst({
      where: {
        id: userId,
        role: UserRole.SUPPORT,
        status: 'ACTIVE',
        businessProfile: {
          is: {
            isActive: true,
            inviteCodes: { some: { code: fixedCode } },
          },
        },
      },
      select: { id: true },
    });
    if (!operator) throw new ForbiddenException('Dedicated operator scope is not configured');

    const invalidAssignment = await this.prisma.user.findFirst({
      where: {
        assignedBusinessId: userId,
        OR: [
          { usedInviteCode: null },
          { usedInviteCode: { is: { code: { not: fixedCode } } } },
        ],
      },
      select: { id: true },
    });
    if (invalidAssignment) {
      throw new ForbiddenException('Dedicated operator customer scope requires repair');
    }
    return true;
  }
}
