# syntax=docker/dockerfile:1.7
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN --mount=type=cache,id=india-trading-pub-cache,target=/root/.pub-cache \
    flutter pub get --enforce-lockfile --verbose

COPY . .
ARG API_BASE_URL=/api
ARG ALLOW_INSECURE_API=true
RUN --mount=type=cache,id=india-trading-pub-cache,target=/root/.pub-cache \
    flutter build web --release --no-pub --pwa-strategy=none --dart-define=API_BASE_URL=${API_BASE_URL} --dart-define=ALLOW_INSECURE_API=${ALLOW_INSECURE_API}

FROM nginx:1.27-alpine AS runner
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
