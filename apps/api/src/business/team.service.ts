import { Injectable, ForbiddenException, NotFoundException, ConflictException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTeamStaffDto } from './team.dto';
@Injectable()
export class TeamService {
  constructor(private readonly prisma: PrismaService) {}
  async actor(id: string) {
    const actor = await this.prisma.user.findUnique({where:{id}, select:{id:true,role:true,status:true}});
    if (!actor || actor.status !== 'ACTIVE' || !['ADMIN','MANAGER'].includes(actor.role)) throw new ForbiddenException();
    return actor;
  }
  async list(actorId: string) {
    const actor = await this.actor(actorId);
    return this.prisma.user.findMany({
      where: actor.role === 'ADMIN' ? {role:'MANAGER'} : {role:'BUSINESS',businessCreatorId:actorId},
      select:{id:true,fullName:true,role:true,status:true,businessProfile:{select:{employeeNo:true,isActive:true}},_count:{select:{assignedCustomers:true,createdBusinessUsers:true}}},
      orderBy:{createdAt:'desc'},
    });
  }
  async create(actorId: string, dto: CreateTeamStaffDto) {
    const actor = await this.actor(actorId);
    const role = actor.role === 'ADMIN' ? 'MANAGER' : 'BUSINESS';
    const passwordHash = await bcrypt.hash(dto.password,12);
    try {
      return await this.prisma.$transaction(async tx => {
        const user = await tx.user.create({
          data:{email:dto.employeeNo.toLowerCase()+'@internal.hnw.local',fullName:dto.fullName,passwordHash,role,businessCreatorId:actorId,
            businessProfile:{create:{employeeNo:dto.employeeNo,isActive:true}}},
          select:{id:true,fullName:true,role:true,status:true,businessProfile:{select:{employeeNo:true}}},
        });
        await tx.auditLog.create({data:{actorId,action:'TEAM_STAFF_CREATED',resource:'USER',resourceId:user.id,metadata:{role}}});
        return user;
      });
    } catch (e) {
      if ((e as {code?:string}).code === 'P2002') throw new ConflictException('Employee number already exists');
      throw e;
    }
  }
  async business(actorId: string, businessId: string) {
    const actor = await this.actor(actorId);
    if (actor.role !== 'MANAGER') throw new ForbiddenException();
    const business = await this.prisma.user.findFirst({where:{id:businessId,role:'BUSINESS',businessCreatorId:actorId},select:{id:true}});
    if (!business) throw new NotFoundException('Business user not found in your team');
    return business.id;
  }
  async audit(actorId: string, targetId: string, action: string) {
    await this.prisma.auditLog.create({data:{actorId,action,resource:'TEAM',resourceId:targetId}});
  }
}
