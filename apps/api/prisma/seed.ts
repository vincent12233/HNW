import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';

import { PrismaClient } from '../src/generated/prisma/client';
import {
  InviteCodeStatus,
  UserRole,
  UserStatus,
} from '../src/generated/prisma/enums';

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('DATABASE_URL is not configured');
}

const adapter = new PrismaPg({ connectionString });
const prisma = new PrismaClient({ adapter });

type StaffSeed = {
  employeeNo: string;
  password: string;
  fullName: string;
  role: UserRole;
  department: string;
};

const staffSeeds: StaffSeed[] = [
  {
    employeeNo: 'ADMIN001',
    password: 'Admin@123456',
    fullName: 'System Administrator',
    role: UserRole.ADMIN,
    department: 'Administration',
  },
  {
    employeeNo: 'FINANCE001',
    password: 'Finance@123456',
    fullName: 'Finance Operator',
    role: UserRole.FINANCE,
    department: 'Finance',
  },
  {
    employeeNo: 'SUPPORT001',
    password: 'Support@123456',
    fullName: 'Customer Support',
    role: UserRole.SUPPORT,
    department: 'Support',
  },
  {
    employeeNo: 'BUSINESS001',
    password: 'Business@123456',
    fullName: 'Relationship Manager',
    role: UserRole.BUSINESS,
    department: 'Business',
  },
];

async function upsertStaff(seed: StaffSeed) {
  const passwordHash = await bcrypt.hash(seed.password, 12);
  const internalEmail = `${seed.employeeNo.toLowerCase()}@internal.hnw.local`;

  return prisma.user.upsert({
    where: {
      email: internalEmail,
    },
    update: {
      passwordHash,
      fullName: seed.fullName,
      phone: null,
      role: seed.role,
      status: UserStatus.ACTIVE,
      businessProfile: {
        upsert: {
          create: {
            employeeNo: seed.employeeNo,
            department: seed.department,
            isActive: true,
          },
          update: {
            employeeNo: seed.employeeNo,
            department: seed.department,
            isActive: true,
          },
        },
      },
    },
    create: {
      email: internalEmail,
      passwordHash,
      fullName: seed.fullName,
      phone: null,
      role: seed.role,
      status: UserStatus.ACTIVE,
      businessProfile: {
        create: {
          employeeNo: seed.employeeNo,
          department: seed.department,
          isActive: true,
        },
      },
    },
    include: {
      businessProfile: true,
    },
  });
}

async function createInviteCodes(businessProfileId: string) {
  const codes = ['HNWBIZ000001', 'HNWBIZ000002', 'HNWBIZ000003'];

  await prisma.inviteCode.createMany({
    data: codes.map((code) => ({
      code,
      businessProfileId,
      status: InviteCodeStatus.UNUSED,
    })),
    skipDuplicates: true,
  });

  return codes;
}

async function main() {
  const users = [];

  for (const seed of staffSeeds) {
    users.push(await upsertStaff(seed));
  }

  const business = users.find((user) => user.role === UserRole.BUSINESS);
  const inviteCodes = business?.businessProfile
    ? await createInviteCodes(business.businessProfile.id)
    : [];

  console.log('Seed data is ready');
  console.table(
    staffSeeds.map((seed) => ({
      role: seed.role,
      employeeNo: seed.employeeNo,
      password: seed.password,
    })),
  );
  console.log('Business invite codes:', inviteCodes.join(', '));
}

main()
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
