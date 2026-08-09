import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  findByPhone(phone: string) {
    return this.prisma.user.findFirst({
      where: {
        phone,
      },
      include: {
        account: true,
        businessProfile: true,
      },
    });
  }

  findByEmployeeNo(employeeNo: string) {
    return this.prisma.user.findFirst({
      where: {
        businessProfile: {
          employeeNo: employeeNo.trim().toUpperCase(),
        },
      },
      include: {
        account: true,
        businessProfile: true,
      },
    });
  }
}
