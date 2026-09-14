import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';
import { randomInt } from 'crypto';

import { PrismaClient } from '../src/generated/prisma/client';
import {
  InviteCodeStatus,
  UserRole,
  UserStatus,
} from '../src/generated/prisma/enums';
import { fixedInviteCode } from '../src/common/fixed-invite';

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

function initialPassword(name: string) {
  const value = process.env[name]?.trim();
  if (!value || value.length < 6) {
    throw new Error(`${name} must contain at least 6 characters`);
  }
  return value;
}

const staffSeeds: StaffSeed[] = [
  {
    employeeNo: 'ADMIN001',
    password: initialPassword('ADMIN_INITIAL_PASSWORD'),
    fullName: 'System Administrator',
    role: UserRole.ADMIN,
    department: 'Administration',
  },
  {
    employeeNo: 'FINANCE001',
    password: initialPassword('FINANCE_INITIAL_PASSWORD'),
    fullName: 'Finance Operator',
    role: UserRole.FINANCE,
    department: 'Finance',
  },
  {
    employeeNo: 'MANAGER001',
    password: initialPassword('MANAGER_INITIAL_PASSWORD'),
    fullName: 'Operations Manager',
    role: UserRole.MANAGER,
    department: 'Customer Operations',
  },
  {
    employeeNo: 'SUPPORT001',
    password: initialPassword('SUPPORT_INITIAL_PASSWORD'),
    fullName: 'Customer Support',
    role: UserRole.SUPPORT,
    department: 'Support',
  },
  {
    employeeNo: 'BUSINESS001',
    password: initialPassword('BUSINESS_INITIAL_PASSWORD'),
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
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const generateCode = () => Array.from(
    { length: 7 },
    () => chars[randomInt(chars.length)],
  ).join('');

  const unused = await prisma.inviteCode.findMany({
    where: {
      businessProfileId,
      status: InviteCodeStatus.UNUSED,
    },
    select: { id: true, code: true },
    orderBy: { createdAt: 'desc' },
  });

  const validExisting = unused.filter((item) => /^[A-HJ-NP-Z2-9]{7}$/.test(item.code));
  const obsoleteIds = unused
    .filter((item) => !/^[A-HJ-NP-Z2-9]{7}$/.test(item.code))
    .map((item) => item.id);

  if (obsoleteIds.length) {
    await prisma.inviteCode.updateMany({
      where: { id: { in: obsoleteIds } },
      data: {
        status: InviteCodeStatus.DISABLED,
        disabledAt: new Date(),
      },
    });
  }

  const codes = validExisting.slice(0, 3).map((item) => item.code);

  while (codes.length < 3) {
    const code = generateCode();
    const duplicate = await prisma.inviteCode.findUnique({
      where: { code },
      select: { id: true },
    });
    if (!duplicate && !codes.includes(code)) codes.push(code);
  }

  await prisma.inviteCode.createMany({
    data: codes.slice(validExisting.slice(0, 3).length).map((code) => ({
      code,
      businessProfileId,
      status: InviteCodeStatus.UNUSED,
    })),
    skipDuplicates: true,
  });

  return codes;
}

async function createFixedOperatorInviteCode(businessProfileId: string) {
  const code = fixedInviteCode();
  await prisma.inviteCode.upsert({
    where: { code },
    update: { businessProfileId, status: InviteCodeStatus.UNUSED, disabledAt: null, expiresAt: null },
    create: { code, businessProfileId, status: InviteCodeStatus.UNUSED },
  });
  return code;
}

async function main() {
  const users = [];

  for (const seed of staffSeeds) {
    users.push(await upsertStaff(seed));
  }

  const business = users.find((user) => user.role === UserRole.BUSINESS);
  const support = users.find((user) => user.role === UserRole.SUPPORT);
  const inviteCodes = business?.businessProfile
    ? await createInviteCodes(business.businessProfile.id)
    : [];

  console.log('Seed data is ready');
  console.table(staffSeeds.map((seed) => ({
    role: seed.role,
    employeeNo: seed.employeeNo,
  })));
  console.log('Business invite codes:', inviteCodes.join(', '));
  const fixedOperatorCode = support?.businessProfile
    ? await createFixedOperatorInviteCode(support.businessProfile.id)
    : null;
  console.log('Dedicated operator fixed invite code:', fixedOperatorCode);

  if (fixedOperatorCode && support) {
    await prisma.user.updateMany({
      where: { usedInviteCode: { code: fixedOperatorCode } },
      data: { assignedBusinessId: support.id },
    });
  }

  const { APP_CONTENT_DEFAULTS } = await import('../src/app-content/app-content.defaults');
  let createdContent = 0;
  for (const entry of APP_CONTENT_DEFAULTS) {
    const locale = entry.locale || 'en';
    const existing = await prisma.appContentEntry.findUnique({
      where: {
        module_key_locale: {
          module: entry.module,
          key: entry.key,
          locale,
        },
      },
    });
    if (existing) continue;
    await prisma.appContentEntry.create({
      data: {
        module: entry.module,
        key: entry.key,
        title: entry.title ?? null,
        body: entry.body,
        locale,
        isActive: entry.isActive ?? true,
        sortOrder: entry.sortOrder ?? 0,
      },
    });
    createdContent += 1;
  }
  console.log(`App content defaults ensured (${createdContent} created)`);
}

main()
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
