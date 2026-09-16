import 'dotenv/config';
import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',

  migrations: {
    path: 'prisma/migrations',
  },

  datasource: {
    // Client generation does not connect to Postgres. Keep `npm ci` and
    // `npm run db:generate` usable in clean environments while migrations and
    // application startup still receive the real URLs from their commands.
    url: process.env.DATABASE_URL ?? 'postgresql://localhost:5432/hnw_generate',
    shadowDatabaseUrl:
      process.env.SHADOW_DATABASE_URL ??
      'postgresql://localhost:5432/hnw_generate_shadow',
  },
});
