FROM node:24-alpine

WORKDIR /app

ENV DATABASE_URL=postgresql://hnw_user:hnw_dev_password@postgres:5432/hnw_trading?schema=public
ENV SHADOW_DATABASE_URL=postgresql://hnw_user:hnw_dev_password@postgres:5432/hnw_trading_shadow?schema=public

COPY package.json package-lock.json prisma.config.ts ./
COPY prisma ./prisma
RUN npm ci

COPY nest-cli.json tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build

EXPOSE 3000

CMD ["sh", "-c", "npm run db:migrate && npm run seed && npm run start:prod"]
