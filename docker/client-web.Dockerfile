FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /src/apps/client
COPY apps/client/pubspec.yaml apps/client/pubspec.lock ./
RUN flutter pub get
COPY apps/client/ ./
RUN flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=/api

FROM nginxinc/nginx-unprivileged:1.27-alpine AS runner
COPY docker/client-web.nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/client-web.security-headers.conf /etc/nginx/security-headers.conf
COPY --from=build /src/apps/client/build/web /usr/share/nginx/html
EXPOSE 8080
USER 101
