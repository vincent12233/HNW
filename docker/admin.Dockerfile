FROM node:24-bookworm-slim

WORKDIR /app
ARG NEXT_PUBLIC_API_URL=http://localhost:3000
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
COPY --chown=node:node apps/admin/package.json apps/admin/package-lock.json ./
RUN npm ci
COPY --chown=node:node apps/admin ./
RUN npm run build && chown -R node:node /app/.next

USER node

CMD ["npm", "run", "start"]
