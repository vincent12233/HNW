FROM node:24-bookworm-slim

WORKDIR /app
COPY apps/admin/package.json apps/admin/package-lock.json ./
RUN npm ci
COPY apps/admin ./

CMD ["npx", "next", "dev", "-H", "0.0.0.0"]
