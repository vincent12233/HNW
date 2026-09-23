FROM node:24-bookworm-slim

WORKDIR /app
COPY --chown=node:node apps/admin/package.json apps/admin/package-lock.json ./
RUN npm ci
COPY --chown=node:node apps/admin ./
RUN mkdir -p /app/.next && chown node:node /app/.next

USER node

CMD ["npx", "next", "dev", "-H", "0.0.0.0"]
