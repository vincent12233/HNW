import { defineConfig } from 'prisma/config';

const migrationsPath = process.env.HNW_UPGRADE_MIGRATIONS_PATH;
const databaseUrl = process.env.DATABASE_URL;
if (!migrationsPath || !databaseUrl) {
  throw new Error('Upgrade test requires HNW_UPGRADE_MIGRATIONS_PATH and DATABASE_URL');
}

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: migrationsPath },
  datasource: { url: databaseUrl },
});
