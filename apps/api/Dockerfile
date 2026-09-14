FROM node:24-alpine

WORKDIR /app

COPY package.json package-lock.json prisma.config.ts ./
COPY prisma ./prisma
# Prisma's postinstall hook only needs valid URL values to generate the client.
# Runtime database URLs are supplied by compose at container start.
ENV DATABASE_URL=postgresql://build:build@localhost:5432/build?schema=public
ENV SHADOW_DATABASE_URL=postgresql://build:build@localhost:5432/build_shadow?schema=public
RUN npm ci

COPY nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
# Generate the Prisma client after copying source so generated runtime files are
# present in the final build output.
RUN npx prisma generate
RUN npm run build

EXPOSE 3000

CMD ["sh", "-c", "npm run db:migrate && npm run seed && npm run start:prod"]
