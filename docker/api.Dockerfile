FROM node:24-bookworm-slim AS base

WORKDIR /app
ENV DATABASE_URL=postgresql://build:build@127.0.0.1:5432/build
ENV SHADOW_DATABASE_URL=postgresql://build:build@127.0.0.1:5432/build_shadow
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

FROM base AS dependencies
COPY apps/api/package.json apps/api/package-lock.json ./
RUN npm ci --ignore-scripts

FROM dependencies AS builder
COPY apps/api ./
RUN npm run db:generate && npm run build

FROM builder AS development
RUN mkdir -p /app/private-objects && chown node:node /app/private-objects
USER node
EXPOSE 3100
CMD ["node", "dist/main.js"]

FROM base AS production-dependencies
COPY apps/api/package.json apps/api/package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts

FROM base AS runner
ARG GIT_COMMIT=unknown
ARG BUILD_TIME=unknown
ENV NODE_ENV=production
ENV GIT_COMMIT=${GIT_COMMIT}
ENV BUILD_TIME=${BUILD_TIME}
LABEL org.opencontainers.image.revision=${GIT_COMMIT}
LABEL org.opencontainers.image.created=${BUILD_TIME}

COPY --from=production-dependencies --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package.json ./package.json
RUN mkdir -p /app/private-objects && chown node:node /app/private-objects

USER node
EXPOSE 3100
CMD ["node", "dist/main.js"]
