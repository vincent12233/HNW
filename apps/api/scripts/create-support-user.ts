import 'dotenv/config';

import * as bcrypt from 'bcrypt';
import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient } from '../src/generated/prisma/client';

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('DATABASE_URL missing');
}

const adapter = new PrismaPg({ connectionString });
const prisma = new PrismaClient({ adapter });

async function main() {
  const employeeNo = 'SUPPORT001';
  const password = process.env.SUPPORT_INITIAL_PASSWORD;
  if (!password || password.length < 12) throw new Error('SUPPORT_INITIAL_PASSWORD must contain at least 12 characters');
  const internalEmail = `${employeeNo.toLowerCase()}@internal.hnw.local`;

  const passwordHash = await bcrypt.hash(password, 12);

  const user = await prisma.user.upsert({
    where: {
      email: internalEmail,
    },
    update: {
      passwordHash,
      fullName: 'HNW Customer Support',
      phone: null,
      role: 'SUPPORT',
      status: 'ACTIVE',
      businessProfile: {
        upsert: {
          create: {
            employeeNo,
            department: 'Support',
            isActive: true,
          },
          update: {
            employeeNo,
            department: 'Support',
            isActive: true,
          },
        },
      },
    },
    create: {
      email: internalEmail,
      passwordHash,
      fullName: 'HNW Customer Support',
      phone: null,
      role: 'SUPPORT',
      status: 'ACTIVE',
      businessProfile: {
        create: {
          employeeNo,
          department: 'Support',
          isActive: true,
        },
      },
    },
    include: {
      businessProfile: true,
    },
  });

  console.log('Support user is ready');
  console.log({ employeeNo: user.businessProfile?.employeeNo, role: user.role });
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
