FROM node:24-bookworm-slim

WORKDIR /app
ARG NEXT_PUBLIC_API_URL=https://api.example.com
ARG NEXT_PUBLIC_BACKEND_ROLE
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_PUBLIC_BACKEND_ROLE=${NEXT_PUBLIC_BACKEND_ROLE}
COPY --chown=node:node apps/admin/package.json apps/admin/package-lock.json ./
RUN npm ci
COPY --chown=node:node apps/admin ./
RUN case "$NEXT_PUBLIC_BACKEND_ROLE" in \
      ADMIN|MANAGER|FINANCE|BUSINESS|SUPPORT) ;; \
      *) echo "NEXT_PUBLIC_BACKEND_ROLE must be ADMIN, MANAGER, FINANCE, BUSINESS, or SUPPORT" >&2; exit 1 ;; \
    esac \
    && npm run build \
    && chown -R node:node /app/.next

USER node

CMD ["npm", "run", "start"]
