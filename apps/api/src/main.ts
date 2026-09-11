import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { randomUUID } from 'crypto';
import { json, NextFunction, Request, Response, urlencoded } from 'express';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './observability/all-exceptions.filter';

type RateEntry = { count: number; resetAt: number };
const rateEntries = new Map<string, RateEntry>();

function isLocalDevelopmentOrigin(origin: string) {
  return /^https?:\/\/(?:localhost|127\.0\.0\.1|10\.(?:\d{1,3}\.){2}\d{1,3}|192\.168\.(?:\d{1,3}\.)?\d{1,3}|172\.(?:1[6-9]|2\d|3[0-1])\.\d{1,3})(?::\d+)?$/i.test(origin);
}

function validateProductionEnvironment() {
  if (process.env.NODE_ENV !== 'production') return;
  const requiredSecrets = [
    'JWT_SECRET',
    'OTC_KEY_ENCRYPTION_SECRET',
    'OBJECT_SIGNING_SECRET',
  ];
  for (const name of requiredSecrets) {
    const value = process.env[name]?.trim() ?? '';
    if (value.length < 32 || /replace|change-me|development/i.test(value)) {
      throw new Error(`${name} must be a random value of at least 32 characters`);
    }
  }
  if (new Set(requiredSecrets.map((name) => process.env[name])).size !== requiredSecrets.length) {
    throw new Error('Production encryption and signing secrets must be different');
  }
  const origins = (process.env.CORS_ORIGINS ?? '').split(',').map((value) => value.trim()).filter(Boolean);
  if (!origins.length || origins.some((origin) => !origin.startsWith('https://'))) {
    throw new Error('CORS_ORIGINS must contain only explicit HTTPS origins in production');
  }
  if (!process.env.VIRUS_SCAN_URL?.startsWith('https://')) {
    throw new Error('VIRUS_SCAN_URL must be configured with HTTPS in production');
  }
}

function requestLimit(path: string) {
  if (path === '/auth/recovery/messages') return 120;
  if (path.startsWith('/auth/')) return 20;
  if (path.startsWith('/kyc/')) return 10;
  if (path === '/otc/orders') return 10;
  if (path.includes('/orders') || path.includes('/withdrawal')) return 60;
  return 300;
}

function securityMiddleware(req: Request, res: Response, next: NextFunction) {
  const startedAt = Date.now();
  const requestId = req.header('x-request-id')?.slice(0, 100) || randomUUID();
  res.setHeader('x-request-id', requestId);
  res.on('finish', () => console.log(JSON.stringify({ level: res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info', event: 'http_request', requestId, method: req.method, path: req.path, statusCode: res.statusCode, durationMs: Date.now() - startedAt, ip: req.ip, userAgent: req.header('user-agent')?.slice(0, 200), timestamp: new Date().toISOString() })));
  res.setHeader('x-content-type-options', 'nosniff');
  res.setHeader('x-frame-options', 'DENY');
  res.setHeader('referrer-policy', 'no-referrer');
  res.setHeader('permissions-policy', 'camera=(), microphone=(), geolocation=()');
  res.setHeader('cross-origin-resource-policy', 'same-site');
  res.setHeader('content-security-policy', "default-src 'none'; frame-ancestors 'none'");
  // Early middleware errors must remain readable by allowed browser clients.
  const requestOrigin = req.header('origin');
  const configuredOrigins = (process.env.CORS_ORIGINS ?? '').split(',').map(value => value.trim());
  if (requestOrigin && (configuredOrigins.includes(requestOrigin) ||
      (process.env.NODE_ENV !== 'production' && isLocalDevelopmentOrigin(requestOrigin)))) {
    res.setHeader('Access-Control-Allow-Origin', requestOrigin);
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    res.vary('Origin');
  }
  if (req.method === 'OPTIONS') { next(); return; }
  // Staff sessions use an HttpOnly cookie. Require an explicitly allowed
  // browser origin for state-changing cookie requests to prevent CSRF.
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method) && req.headers.cookie?.match(/(?:^|;\s*)staff_access(?:_[a-z]+)?=/)) {
    const origin = req.header('origin');
    const allowedOrigins = (process.env.CORS_ORIGINS ?? '').split(',').map((value) => value.trim()).filter(Boolean);
    const localOrigin = process.env.NODE_ENV !== 'production' && !!origin && isLocalDevelopmentOrigin(origin);
    if (!origin || (!allowedOrigins.includes(origin) && !localOrigin)) {
      res.status(403).json({ statusCode: 403, message: 'Origin verification failed', requestId });
      return;
    }
  }
  if (process.env.NODE_ENV === 'production') {
    res.setHeader('strict-transport-security', 'max-age=31536000; includeSubDomains');
  }

  const now = Date.now();
  const windowMs = 60_000;
  const key = `${req.ip}:${req.method}:${req.path}`;
  const current = rateEntries.get(key);
  const entry = !current || current.resetAt <= now
    ? { count: 0, resetAt: now + windowMs }
    : current;
  entry.count += 1;
  rateEntries.set(key, entry);
  const limit = requestLimit(req.path);
  res.setHeader('x-ratelimit-limit', limit);
  res.setHeader('x-ratelimit-remaining', Math.max(0, limit - entry.count));
  if (entry.count > limit) {
    res.setHeader('retry-after', Math.ceil((entry.resetAt - now) / 1000));
    res.status(429).json({ statusCode: 429, message: 'Too many requests', requestId });
    return;
  }
  if (rateEntries.size > 10_000) {
    for (const [entryKey, value] of rateEntries) {
      if (value.resetAt <= now) rateEntries.delete(entryKey);
    }
  }
  next();
}

async function bootstrap() {
  validateProductionEnvironment();
  const app = await NestFactory.create(AppModule);

  app.getHttpAdapter().getInstance().set('trust proxy', 1);
  app.use(securityMiddleware);

  // KYC includes two ID files (15 MB each), a selfie (2 MB) and a signature (1 MB). Base64 increases payload size by
  // roughly one third; KycService enforces each individual file limit.
  app.use(json({ limit: '48mb' }));
  app.use(urlencoded({ extended: true, limit: '48mb' }));

  const allowedOrigins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  app.enableCors({
    origin(origin: string | undefined, callback: (error: Error | null, allow?: boolean) => void) {
      if (!origin) {
        callback(null, true);
        return;
      }

      const isLocalDevOrigin = process.env.NODE_ENV !== 'production' && isLocalDevelopmentOrigin(origin);

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
