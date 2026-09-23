FROM node:24-bookworm-slim

WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY apps/api/package.json apps/api/package-lock.json ./
ENV DATABASE_URL=postgresql://build:build@127.0.0.1:5432/build
ENV SHADOW_DATABASE_URL=postgresql://build:build@127.0.0.1:5432/build_shadow
RUN npm ci --ignore-scripts
COPY apps/api ./
RUN npm run db:generate && npm run build \
    && mkdir -p /app/private-objects \
    && chown -R node:node /app

USER node

EXPOSE 3100
CMD ["node", "dist/main.js"]
