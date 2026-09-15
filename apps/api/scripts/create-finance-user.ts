import 'dotenv/config';

import * as bcrypt from 'bcrypt';
import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient } from '../src/generated/prisma/client';
import { UserRole, UserStatus } from '../src/generated/prisma/enums';

if (process.env.NODE_ENV === 'production') {
  throw new Error(
    'create-finance-user.ts refuses to run when NODE_ENV=production (use seed once, then rotate passwords in-app)',
  );
}

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('DATABASE_URL is not configured');
}

const adapter = new PrismaPg({ connectionString });
const prisma = new PrismaClient({ adapter });

async function main() {
  const employeeNo = 'FINANCE001';
  const password = process.env.FINANCE_INITIAL_PASSWORD;
  if (!password || password.length < 12) {
    throw new Error('FINANCE_INITIAL_PASSWORD must contain at least 12 characters');
  }
  const passwordHash = await bcrypt.hash(password, 12);
  const internalEmail = `${employeeNo.toLowerCase()}@internal.hnw.local`;

  const finance = await prisma.user.upsert({
    where: {
      email: internalEmail,
    },
    // Do not overwrite passwordHash on update — operators may have rotated credentials.
    update: {
      fullName: 'Finance Operator',
      role: UserRole.FINANCE,
      status: UserStatus.ACTIVE,
      businessProfile: {
        upsert: {
          create: {
            employeeNo,
            department: 'Finance',
            isActive: true,
          },
          update: {
            employeeNo,
            department: 'Finance',
            isActive: true,
          },
        },
      },
    },
    create: {
      email: internalEmail,
      passwordHash,
      fullName: 'Finance Operator',
      role: UserRole.FINANCE,
      status: UserStatus.ACTIVE,
      businessProfile: {
        create: {
          employeeNo,
          department: 'Finance',
          isActive: true,
        },
      },
    },
    include: {
      businessProfile: true,
    },
  });

  console.log('Finance user ready');
  console.log(`Employee No: ${finance.businessProfile?.employeeNo}`);
  console.log('Password was read securely from FINANCE_INITIAL_PASSWORD (create only)');
}

main()
  .catch((error) => {
    console.error('Failed to create finance user:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
