import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { randomUUID } from 'crypto';
import { json, NextFunction, Request, Response, urlencoded } from 'express';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './observability/all-exceptions.filter';

type RateEntry = { count: number; resetAt: number };
const rateEntries = new Map<string, RateEntry>();

function requestLimit(path: string) {
  if (path.startsWith('/auth/')) return 20;
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
  if (process.env.NODE_ENV === 'production') {
    res.setHeader('strict-transport-security', 'max-age=31536000; includeSubDomains');
  }

  const now = Date.now();
  const windowMs = 60_000;
  const key = `${req.ip}:${req.path.startsWith('/auth/') ? 'auth' : 'api'}`;
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
  const app = await NestFactory.create(AppModule);

  app.getHttpAdapter().getInstance().set('trust proxy', 1);
  app.use(securityMiddleware);

  // Aadhaar KYC can contain two images. Base64 increases payload size by
  // roughly one third, while KycService still enforces 8 MB per file.
  app.use(json({ limit: '24mb' }));
  app.use(urlencoded({ extended: true, limit: '24mb' }));

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

      const isLocalDevOrigin = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);

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

  await app.listen(process.env.PORT ?? 3000);
}

void bootstrap();
