FROM node:24-bookworm-slim AS development

WORKDIR /app
COPY --chown=node:node apps/admin/package.json apps/admin/package-lock.json ./
RUN npm ci
COPY --chown=node:node apps/admin ./
RUN chown node:node /app && mkdir -p /app/.next && chown node:node /app/.next
USER node
CMD ["npm", "run", "dev"]

FROM development AS builder
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_BACKEND_ROLE
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_PUBLIC_BACKEND_ROLE=${NEXT_PUBLIC_BACKEND_ROLE}
RUN case "$NEXT_PUBLIC_API_URL" in \
      https://* ) ;; \
      *) echo "NEXT_PUBLIC_API_URL must be an HTTPS URL" >&2; exit 1 ;; \
    esac \
    && case "$NEXT_PUBLIC_API_URL" in \
      *example.com* ) echo "NEXT_PUBLIC_API_URL must not use an example domain" >&2; exit 1 ;; \
    esac \
    && case "$NEXT_PUBLIC_BACKEND_ROLE" in \
      ADMIN|MANAGER|FINANCE|BUSINESS|SUPPORT) ;; \
      *) echo "NEXT_PUBLIC_BACKEND_ROLE must be ADMIN, MANAGER, FINANCE, BUSINESS, or SUPPORT" >&2; exit 1 ;; \
    esac \
    && npm run build

FROM node:24-bookworm-slim AS runner

WORKDIR /app
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_BACKEND_ROLE
ENV NODE_ENV=production
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
ENV NEXT_PUBLIC_BACKEND_ROLE=${NEXT_PUBLIC_BACKEND_ROLE}
ENV HOSTNAME=0.0.0.0

COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
COPY --from=builder --chown=node:node /app/public ./public

USER node

CMD ["node", "server.js"]
