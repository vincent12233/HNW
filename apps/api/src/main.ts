import 'dotenv/config';
import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { randomUUID } from 'crypto';
import { json, NextFunction, Request, Response, urlencoded } from 'express';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './observability/all-exceptions.filter';
import { businessFailureEvent } from './observability/business-events';
import { isLocalDevelopmentOrigin } from './common/local-development-origin';
import {
  createRateLimitStore,
  normalizeRateLimitPath,
  type RateLimitStore,
} from './common/rate-limit-store';
import { resolveTrustProxyHops } from './common/trust-proxy';

const httpLogger = new Logger('HttpAudit');

function isLoopbackOrPrivateHostname(hostname: string) {
  const host = hostname.toLowerCase().replace(/^\[|\]$/g, '');
  if (
    host === 'localhost' ||
    host === '127.0.0.1' ||
    host === '::1' ||
    host === '0.0.0.0'
  ) {
    return true;
  }
  if (/^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(host)) return true;
  if (/^192\.168\.\d{1,3}\.\d{1,3}$/.test(host)) return true;
  if (/^172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3}$/.test(host)) return true;
  return false;
}

function assertPublicHttpsUrl(label: string, value: string) {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`${label} must be a valid HTTPS URL in production`);
  }
  if (parsed.protocol !== 'https:') {
    throw new Error(`${label} must use HTTPS in production`);
  }
  if (isLoopbackOrPrivateHostname(parsed.hostname)) {
    throw new Error(
      `${label} must not target localhost or private network hosts in production`,
    );
  }
}

function validateProductionEnvironment() {
  if (process.env.NODE_ENV !== 'production') return;
  resolveTrustProxyHops();
  const requiredSecrets = [
    'JWT_SECRET',
    'OTC_KEY_ENCRYPTION_SECRET',
    'OBJECT_SIGNING_SECRET',
    'TWO_FACTOR_ENCRYPTION_KEY',
  ];
  for (const name of requiredSecrets) {
    const value = process.env[name]?.trim() ?? '';
    if (value.length < 32 || /replace|change-me|development/i.test(value)) {
      throw new Error(
        `${name} must be a random value of at least 32 characters`,
      );
    }
  }
  if (
    new Set(requiredSecrets.map((name) => process.env[name]?.trim())).size !==
    requiredSecrets.length
  ) {
    throw new Error(
      'Production encryption and signing secrets must be different',
    );
  }
  const inviteCode = process.env.ADMIN_FIXED_INVITE_CODE?.trim() ?? '';
  if (
    inviteCode.length < 12 ||
    /replace|change-me|adminfixed2026/i.test(inviteCode)
  ) {
    throw new Error(
      'ADMIN_FIXED_INVITE_CODE must be set to a strong unique value in production',
    );
  }
  if (
    requiredSecrets.some((name) => process.env[name]?.trim() === inviteCode)
  ) {
    throw new Error(
      'ADMIN_FIXED_INVITE_CODE must be distinct from encryption secrets',
    );
  }
  const origins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  if (!origins.length) {
    throw new Error(
      'CORS_ORIGINS must contain only explicit HTTPS origins in production',
    );
  }
  for (const origin of origins) {
    assertPublicHttpsUrl('CORS_ORIGINS entry', origin);
  }
  assertPublicHttpsUrl(
    'VIRUS_SCAN_URL',
    process.env.VIRUS_SCAN_URL?.trim() ?? '',
  );
  const privateRoot = process.env.PRIVATE_OBJECT_ROOT?.trim() ?? '';
  if (!privateRoot || !privateRoot.startsWith('/')) {
    throw new Error(
      'PRIVATE_OBJECT_ROOT must be an absolute filesystem path in production',
    );
  }
  if (!process.env.RATE_LIMIT_REDIS_URL?.trim()) {
    throw new Error('RATE_LIMIT_REDIS_URL is required in production');
  }
}

function requestLimit(path: string) {
  if (
    path === '/auth/login' ||
    path === '/auth/google' ||
    path === '/auth/biometric' ||
    path.startsWith('/auth/recovery')
  ) {
    return 10;
  }
  if (path.startsWith('/auth/')) return 20;
  if (path.startsWith('/kyc/')) return 10;
  if (path === '/otc/orders') return 10;
  if (
    path.includes('/deposit') ||
    path.includes('/withdrawal') ||
    path.includes('/loans') ||
    (path.includes('/accounts/') &&
      (path.includes('/credit') || path.includes('/debit')))
  ) {
    return 30;
  }
  if (path.includes('/orders') || path.includes('/withdrawal')) return 60;
  return 300;
}

function securityMiddleware(rateLimitStore: RateLimitStore) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const startedAt = Date.now();
    const requestId = req.header('x-request-id')?.slice(0, 100) || randomUUID();
    res.setHeader('x-request-id', requestId);
    res.on('finish', () => {
      const durationMs = Date.now() - startedAt;
      const timestamp = new Date().toISOString();
      const payload = JSON.stringify({
        level:
          res.statusCode >= 500
            ? 'error'
            : res.statusCode >= 400
              ? 'warn'
              : 'info',
        event: 'http_request',
        requestId,
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        durationMs,
        ip: req.ip,
        userAgent: req.header('user-agent')?.slice(0, 200),
        timestamp,
      });
      if (res.statusCode >= 500) httpLogger.error(payload);
      else if (res.statusCode >= 400) httpLogger.warn(payload);
      else httpLogger.log(payload);

      const event = businessFailureEvent(req.method, req.path, res.statusCode);
      if (event) {
        httpLogger.warn(
          JSON.stringify({
            level: 'warn',
            event,
            requestId,
            path: normalizeRateLimitPath(req.path),
            statusCode: res.statusCode,
            durationMs,
            timestamp,
          }),
        );
      }
    });
    res.setHeader('x-content-type-options', 'nosniff');
    res.setHeader('x-frame-options', 'DENY');
    res.setHeader('referrer-policy', 'no-referrer');
    res.setHeader(
      'permissions-policy',
      'camera=(), microphone=(), geolocation=()',
    );
    res.setHeader('cross-origin-resource-policy', 'same-site');
    res.setHeader(
      'content-security-policy',
      "default-src 'none'; frame-ancestors 'none'",
    );
    // Early middleware errors must remain readable by allowed browser clients.
    const requestOrigin = req.header('origin');
    const configuredOrigins = (process.env.CORS_ORIGINS ?? '')
      .split(',')
      .map((value) => value.trim());
    if (
      requestOrigin &&
      (configuredOrigins.includes(requestOrigin) ||
        (process.env.NODE_ENV !== 'production' &&
          isLocalDevelopmentOrigin(requestOrigin)))
    ) {
      res.setHeader('Access-Control-Allow-Origin', requestOrigin);
      res.setHeader('Access-Control-Allow-Credentials', 'true');
      res.vary('Origin');
    }
    if (req.method === 'OPTIONS') {
      next();
      return;
    }
    // Staff sessions use an HttpOnly cookie. Require an explicitly allowed
    // browser origin for state-changing cookie requests to prevent CSRF.
    if (
      ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method) &&
      req.headers.cookie?.match(/(?:^|;\s*)staff_access(?:_[a-z]+)?=/)
    ) {
      const origin = req.header('origin');
      const allowedOrigins = (process.env.CORS_ORIGINS ?? '')
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean);
      const localOrigin =
        process.env.NODE_ENV !== 'production' &&
        !!origin &&
        isLocalDevelopmentOrigin(origin);
      if (!origin || (!allowedOrigins.includes(origin) && !localOrigin)) {
        res.status(403).json({
          statusCode: 403,
          message: 'Origin verification failed',
          requestId,
        });
        return;
      }
    }
    if (process.env.NODE_ENV === 'production') {
      res.setHeader(
        'strict-transport-security',
        'max-age=31536000; includeSubDomains',
      );
    }

    const windowMs = 60_000;
    const key = `${req.ip}:${req.method}:${normalizeRateLimitPath(req.path)}`;
    let entry;
    try {
      entry = await rateLimitStore.consume(key, windowMs);
    } catch (error) {
      httpLogger.error(
        JSON.stringify({ event: 'rate_limit_store_error', requestId, error }),
      );
      res.status(503).json({
        statusCode: 503,
        message: 'Request protection is temporarily unavailable',
        requestId,
      });
      return;
    }
    const limit = requestLimit(req.path);
    res.setHeader('x-ratelimit-limit', limit);
    res.setHeader('x-ratelimit-remaining', Math.max(0, limit - entry.count));
    if (entry.count > limit) {
      const retryAfterSeconds = Math.max(
        1,
        Math.ceil((entry.resetAt - Date.now()) / 1000),
      );
      res.setHeader('retry-after', retryAfterSeconds);
      httpLogger.warn(
        JSON.stringify({
          level: 'warn',
          event: 'rate_limit_blocked',
          requestId,
          method: req.method,
          path: normalizeRateLimitPath(req.path),
          limit,
          count: entry.count,
          retryAfterSeconds,
          timestamp: new Date().toISOString(),
        }),
      );
      res
        .status(429)
        .json({ statusCode: 429, message: 'Too many requests', requestId });
      return;
    }
    next();
  };
}

async function bootstrap() {
  validateProductionEnvironment();
  const rateLimitStore = await createRateLimitStore();
  const app = await NestFactory.create(AppModule);

  const expressApp = app.getHttpAdapter().getInstance() as {
    set: (setting: string, value: unknown) => unknown;
  };
  expressApp.set('trust proxy', resolveTrustProxyHops());
  app.use(securityMiddleware(rateLimitStore));
  app.enableShutdownHooks();
  process.once('SIGTERM', () => void rateLimitStore.close());
  process.once('SIGINT', () => void rateLimitStore.close());

  // KYC includes two ID files (15 MB each), a selfie (2 MB) and a signature (1 MB). Base64 increases payload size by
  // roughly one third; KycService enforces each individual file limit.
  app.use(json({ limit: '48mb' }));
  app.use(urlencoded({ extended: true, limit: '48mb' }));

  const allowedOrigins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  app.enableCors({
    origin(
      origin: string | undefined,
      callback: (error: Error | null, allow?: boolean) => void,
    ) {
      if (!origin) {
        callback(null, true);
        return;
      }

      const isLocalDevOrigin =
        process.env.NODE_ENV !== 'production' &&
        isLocalDevelopmentOrigin(origin);

      if (isLocalDevOrigin || allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }

      callback(new Error('Origin is not allowed by CORS'));
    },
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());

  await app.listen(process.env.PORT ?? 3000, process.env.HOST ?? '0.0.0.0');
}

void bootstrap();
